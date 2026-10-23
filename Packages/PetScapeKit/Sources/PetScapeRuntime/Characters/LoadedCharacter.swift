import Foundation
import PetScapeCore
import PetScapeRendering

/// A validated pack whose image frames are decoded in behavior-family groups on demand.
@MainActor public final class LoadedCharacter: Sendable {
    public let definition: CharacterDefinition
    /// Decoded frame pixel size (the cache key used for every frame of this character).
    public let pixelSize: Int
    /// Non-fatal findings: clip errors (those clips fall back) and warnings.
    private let initialIssues: [ManifestIssue]
    /// Why the real pack could not be used; `nil` when it loaded.
    public let failure: CharacterLoadError?

    private let catalog: CharacterFrameCatalog

    public init(
        definition: CharacterDefinition,
        pixelSize: Int,
        catalog: CharacterFrameCatalog,
        issues: [ManifestIssue] = [],
        failure: CharacterLoadError? = nil
    ) {
        self.definition = definition
        self.pixelSize = pixelSize
        self.catalog = catalog
        initialIssues = issues
        self.failure = failure
    }

    /// Decoded frames by clip name, in clip frame order. This includes only families loaded so far.
    public var frames: [String: [FrameImage]] { catalog.frames }

    /// Decoded pixel bytes currently held for this character; changes as families are loaded.
    public var decodedByteCount: Int { catalog.decodedByteCount }

    public var issues: [ManifestIssue] { initialIssues + catalog.lazyIssues }

    public var isPlaceholder: Bool { failure != nil }

    /// Loaded, but some clips are invalid and use their fallbacks.
    public var isDegraded: Bool { failure == nil && issues.contains { $0.severity == .error } }

    /// The image for a frame chosen by `AnimationController`, or `nil` for an unloaded/out-of-range reference.
    public func frame(_ reference: AnimationFrameRef) -> FrameImage? { catalog.frame(reference) }

    /// An already-decoded frame used while another behavior family is being decoded.
    public func fallbackFrame(for reference: AnimationFrameRef) -> FrameImage? {
        frame(reference) ?? catalog.defaultFrame
    }

    /// Decodes every clip in the family containing `clipName`, once per family.
    @discardableResult
    public func loadBehaviorFamily(containing clipName: String) async -> Bool {
        await catalog.loadBehaviorFamily(containing: clipName)
    }

    public func isBehaviorFamilyLoaded(containing clipName: String) -> Bool {
        catalog.isBehaviorFamilyLoaded(containing: clipName)
    }

    public func hasAttemptedBehaviorFamily(containing clipName: String) -> Bool {
        catalog.hasAttemptedBehaviorFamily(containing: clipName)
    }
}

/// Main-actor cache coordinator; image decoding itself is dispatched off-main by FrameImageStore.
@MainActor public final class CharacterFrameCatalog: Sendable {
    private let definition: CharacterDefinition
    private let packURL: URL?
    private let pixelSize: Int
    private let store: FrameImageStore
    private var loadedFamilyNames: Set<String>
    private var attemptedFamilyNames: Set<String>
    public private(set) var lazyIssues: [ManifestIssue] = []

    public init(
        definition: CharacterDefinition,
        packURL: URL?,
        pixelSize: Int,
        store: FrameImageStore,
        loadedFamilies: Set<String>
    ) {
        self.definition = definition
        self.packURL = packURL
        self.pixelSize = pixelSize
        self.store = store
        loadedFamilyNames = loadedFamilies
        attemptedFamilyNames = loadedFamilies
    }

    public var decodedByteCount: Int { store.decodedByteCount(for: definition.id) }

    public var frames: [String: [FrameImage]] {
        var result: [String: [FrameImage]] = [:]
        for (name, clip) in definition.clips {
            let images = clip.frames.compactMap {
                store.frame(character: definition.id, source: $0.source, pixelSize: pixelSize)
            }
            if images.count == clip.frames.count { result[name] = images }
        }
        return result
    }

    public var defaultFrame: FrameImage? {
        guard let clip = definition.clips[definition.defaultClipName], let source = clip.frames.first?.source else {
            return nil
        }
        return store.frame(character: definition.id, source: source, pixelSize: pixelSize)
    }

    public func frame(_ reference: AnimationFrameRef) -> FrameImage? {
        guard let clip = definition.clips[reference.clip], clip.frames.indices.contains(reference.frameIndex) else {
            return nil
        }
        return store.frame(
            character: definition.id, source: clip.frames[reference.frameIndex].source, pixelSize: pixelSize)
    }

    public func isBehaviorFamilyLoaded(containing clipName: String) -> Bool {
        loadedFamilyNames.contains(Self.family(for: clipName))
    }

    public func hasAttemptedBehaviorFamily(containing clipName: String) -> Bool {
        attemptedFamilyNames.contains(Self.family(for: clipName))
    }

    @discardableResult
    public func loadBehaviorFamily(containing clipName: String) async -> Bool {
        let family = Self.family(for: clipName)
        guard !attemptedFamilyNames.contains(family) else { return loadedFamilyNames.contains(family) }
        guard let packURL else { return false }
        let clips = definition.clips.filter { Self.family(for: $0.key) == family }
        let sources = Set(clips.values.flatMap { $0.frames.map(\.source) })
        let result = await store.preload(
            character: definition.id, packURL: packURL, sources: sources, pixelSize: pixelSize)
        let loaded = clips.values.allSatisfy { clip in
            clip.frames.allSatisfy {
                store.frame(character: definition.id, source: $0.source, pixelSize: pixelSize) != nil
            }
        }
        if !result.failures.isEmpty {
            Log.assets.error(
                "Lazy clip load failed for '\(clipName, privacy: .public)': \(result.failures.count) source(s)")
            for (name, clip) in clips {
                for frame in clip.frames {
                    guard let error = result.failures[frame.source.imagePath] else { continue }
                    let code: ManifestIssueCode =
                        switch error {
                        case .missingFile: .missingFile
                        case .undecodable: .undecodableImage
                        }
                    let issue = ManifestIssue(
                        code: code, severity: .error, scope: .clip(name), detail: frame.source.imagePath)
                    if !lazyIssues.contains(issue) { lazyIssues.append(issue) }
                }
            }
        }
        attemptedFamilyNames.insert(family)
        if loaded { loadedFamilyNames.insert(family) }
        return loaded
    }

    static func family(for name: String) -> String {
        let normalized = name.lowercased().replacingOccurrences(of: "_", with: "-")
        if ["walk", "idle", "turn", "climb"].contains(normalized) { return "locomotion" }
        if ["jump", "jump-start", "jump-air", "fall", "land", "landing"].contains(normalized) { return "airborne" }
        if ["sit", "sit-down", "sitting", "stand-up", "lie-down", "sleep", "wake-up", "stretch"].contains(normalized) {
            return "rest"
        }
        if ["observe", "look-around", "curious", "picked-up", "held", "react", "reacting"].contains(normalized) {
            return "interaction"
        }
        return "clip:\(normalized)"
    }
}
