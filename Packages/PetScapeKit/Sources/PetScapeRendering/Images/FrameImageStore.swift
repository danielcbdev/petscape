import CoreGraphics
import Foundation
import PetScapeCore

/// Identifies one cached frame: character, source (file or sheet cell) and decoded pixel size.
public struct FrameImageKey: Hashable, Sendable {
    public var character: CharacterID
    public var source: AnimationClip.FrameSource
    public var pixelSize: Int

    public init(character: CharacterID, source: AnimationClip.FrameSource, pixelSize: Int) {
        self.character = character
        self.source = source
        self.pixelSize = pixelSize
    }
}

/// What `FrameImageStore.preload` found, per pack-relative image path.
public struct FramePreloadResult: Sendable {
    /// Input for `ManifestValidator`'s file checks (`missingFile`, `undecodableImage`, `canvasMismatch`).
    public var probes: [String: ImageProbe]
    public var failures: [String: ImageDecodingError]

    public init(probes: [String: ImageProbe] = [:], failures: [String: ImageDecodingError] = [:]) {
        self.probes = probes
        self.failures = failures
    }
}

/// Decoded, downsampled frame images with their hit masks, shared by pet layers and hit testing
/// (docs/architecture/animation-system.md#loading-caching-memory).
///
/// Decoding runs in parallel off the main actor; the cache itself lives on the main actor, where the
/// renderer reads it every frame without locks.
public final class FrameImageStore {
    private struct SourceKey: Hashable {
        var character: CharacterID
        var path: String
        var pixelSize: Int
    }

    /// One file to decode: a plain frame image, or a sheet together with the cells that are needed.
    nonisolated private enum Job: Hashable, Sendable {
        case image(String)
        case sheet(AnimationClip.Sheet)

        var path: String {
            switch self {
            case .image(let path): path
            case .sheet(let sheet): sheet.image
            }
        }

        var sheet: AnimationClip.Sheet? {
            switch self {
            case .image: nil
            case .sheet(let sheet): sheet
            }
        }
    }

    nonisolated private struct DecodedJob: Sendable {
        var frames: [(AnimationClip.FrameSource, FrameImage)]
        var byteCount: Int
        var sourcePixelWidth: Int
        var sourcePixelHeight: Int
    }

    private let decoder: ImageDecoder
    private var frames: [FrameImageKey: FrameImage] = [:]
    private var decodedBytes: [SourceKey: Int] = [:]

    public init(decoder: ImageDecoder = ImageDecoder()) {
        self.decoder = decoder
    }

    /// `ceil(max(displaySize) × maxBackingScale × maxUserScale)`; 96 pt × 2 × 1.5 = 288 px for the MVP cat.
    public static func targetPixelSize(
        for displaySize: CharacterManifest.Size,
        maxBackingScale: Double = 2,
        maxUserScale: Double = 1.5
    ) -> Int {
        Int((max(displaySize.width, displaySize.height) * maxBackingScale * maxUserScale).rounded(.up))
    }

    /// Decodes and caches every source that is not cached yet. Missing or broken files are reported, not thrown.
    public func preload(
        character: CharacterID,
        packURL: URL,
        sources: some Sequence<AnimationClip.FrameSource>,
        pixelSize: Int
    ) async -> FramePreloadResult {
        var cells: [AnimationClip.Sheet: Set<Int>] = [:]
        var jobs: Set<Job> = []
        for source in sources
        where frames[FrameImageKey(character: character, source: source, pixelSize: pixelSize)] == nil {
            switch source {
            case .image(let path):
                jobs.insert(.image(path))
            case .sheetCell(let sheet, let cell):
                jobs.insert(.sheet(sheet))
                cells[sheet, default: []].insert(cell)
            }
        }

        let decoder = decoder
        var result = FramePreloadResult()
        await withTaskGroup(of: (Job, Result<DecodedJob, ImageDecodingError>).self) { group in
            for job in jobs {
                let neededCells = job.sheet.flatMap { cells[$0] } ?? []
                group.addTask {
                    (
                        job,
                        await Self.run(
                            job, cells: neededCells, packURL: packURL, pixelSize: pixelSize, decoder: decoder)
                    )
                }
            }
            for await (job, outcome) in group {
                switch outcome {
                case .success(let decoded):
                    for (source, frame) in decoded.frames {
                        frames[FrameImageKey(character: character, source: source, pixelSize: pixelSize)] = frame
                    }
                    decodedBytes[SourceKey(character: character, path: job.path, pixelSize: pixelSize)] =
                        decoded.byteCount
                    result.probes[job.path] = .decoded(
                        pixelWidth: decoded.sourcePixelWidth, pixelHeight: decoded.sourcePixelHeight)
                case .failure(let error):
                    result.failures[job.path] = error
                    switch error {
                    case .missingFile: result.probes[job.path] = .missing
                    case .undecodable: result.probes[job.path] = .undecodable
                    }
                }
            }
        }
        return result
    }

    /// Checks source-file metadata without decoding pixel buffers, for manifest validation before lazy loading.
    public func probe(
        packURL: URL,
        sources: some Sequence<AnimationClip.FrameSource>
    ) async -> FramePreloadResult {
        var jobs: Set<Job> = []
        for source in sources {
            switch source {
            case .image(let path): jobs.insert(.image(path))
            case .sheetCell(let sheet, _): jobs.insert(.sheet(sheet))
            }
        }
        var result = FramePreloadResult()
        await withTaskGroup(of: (String, Result<(Int, Int), ImageDecodingError>).self) { group in
            for job in jobs {
                group.addTask {
                    let outcome = await Self.probeSource(at: packURL.appending(path: job.path), label: job.path)
                    return (job.path, outcome)
                }
            }
            for await (path, outcome) in group {
                switch outcome {
                case .success(let (width, height)):
                    result.probes[path] = .decoded(pixelWidth: width, pixelHeight: height)
                case .failure(let error):
                    result.failures[path] = error
                    switch error {
                    case .missingFile: result.probes[path] = .missing
                    case .undecodable: result.probes[path] = .undecodable
                    }
                }
            }
        }
        return result
    }

    /// The cached frame for `source`, or `nil` if it was never preloaded or failed to decode.
    public func frame(character: CharacterID, source: AnimationClip.FrameSource, pixelSize: Int) -> FrameImage? {
        frames[FrameImageKey(character: character, source: source, pixelSize: pixelSize)]
    }

    /// Adds a frame that was not decoded from a file (e.g. the placeholder silhouette).
    public func insert(_ frame: FrameImage, character: CharacterID, source: AnimationClip.FrameSource, pixelSize: Int) {
        frames[FrameImageKey(character: character, source: source, pixelSize: pixelSize)] = frame
        decodedBytes[SourceKey(character: character, path: source.imagePath, pixelSize: pixelSize)] =
            frame.image.bytesPerRow * frame.image.height
    }

    /// Bytes of decoded pixel data held by the cache (a sheet is counted once, not per cell).
    public var decodedByteCount: Int {
        decodedBytes.values.reduce(0, +)
    }

    public func decodedByteCount(for character: CharacterID) -> Int {
        decodedBytes.filter { $0.key.character == character }.values.reduce(0, +)
    }

    public var cachedFrameCount: Int { frames.count }

    /// Drops everything cached for `character` (no pet uses it any more).
    public func evict(character: CharacterID) {
        frames = frames.filter { $0.key.character != character }
        decodedBytes = decodedBytes.filter { $0.key.character != character }
    }

    /// Drops decoded frames for this character except for the sources needed by `sources`.
    public func evict(character: CharacterID, keeping sources: Set<AnimationClip.FrameSource>) {
        frames = frames.filter { key, _ in
            key.character != character || sources.contains(key.source)
        }
        let paths = Set(sources.map(\.imagePath))
        decodedBytes = decodedBytes.filter { key, _ in
            key.character != character || paths.contains(key.path)
        }
    }

    @concurrent
    nonisolated private static func run(
        _ job: Job,
        cells: Set<Int>,
        packURL: URL,
        pixelSize: Int,
        decoder: ImageDecoder
    ) async -> Result<DecodedJob, ImageDecodingError> {
        do {
            let url = packURL.appending(path: job.path)
            switch job {
            case .image(let path):
                let decoded = try await decoder.decode(contentsOf: url, maxPixelSize: pixelSize, label: path)
                guard let frame = FrameImage(image: decoded.image) else { throw ImageDecodingError.undecodable(path) }
                return .success(
                    DecodedJob(
                        frames: [(.image(path), frame)],
                        byteCount: decoded.image.bytesPerRow * decoded.image.height,
                        sourcePixelWidth: decoded.sourcePixelWidth, sourcePixelHeight: decoded.sourcePixelHeight))
            case .sheet(let sheet):
                let decoded = try await decoder.decodeSheet(
                    contentsOf: url, columns: sheet.columns, rows: sheet.rows, cellMaxPixelSize: pixelSize,
                    label: sheet.image)
                var frames: [(AnimationClip.FrameSource, FrameImage)] = []
                for cell in cells.sorted() where decoded.cells.indices.contains(cell) {
                    guard let frame = FrameImage(image: decoded.cells[cell]) else {
                        throw ImageDecodingError.undecodable(sheet.image)
                    }
                    frames.append((.sheetCell(sheet, cell: cell), frame))
                }
                let image = decoded.sheet.image
                return .success(
                    DecodedJob(
                        frames: frames, byteCount: image.bytesPerRow * image.height,
                        sourcePixelWidth: decoded.sheet.sourcePixelWidth,
                        sourcePixelHeight: decoded.sheet.sourcePixelHeight))
            }
        } catch let error as ImageDecodingError {
            return .failure(error)
        } catch {
            return .failure(.undecodable(job.path))
        }
    }

    @concurrent
    nonisolated private static func probeSource(at url: URL, label: String) async
        -> Result<(Int, Int), ImageDecodingError>
    {
        do {
            return .success(try ImageDecoder.sourcePixelSize(of: url, label: label))
        } catch {
            return .failure(error)
        }
    }
}
