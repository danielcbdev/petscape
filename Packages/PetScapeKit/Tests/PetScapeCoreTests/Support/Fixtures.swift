import Foundation
import Testing

@testable import PetScapeCore

/// Loads the JSON manifest fixtures (Tests/PetScapeCoreTests/Fixtures/Manifests) and builds test clips.
enum Fixtures {
    struct MissingFixture: Error {
        var name: String
    }

    static func manifestData(_ name: String) throws -> Data {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/Manifests")
        else { throw MissingFixture(name: name) }
        return try Data(contentsOf: url)
    }

    static func decoded(_ name: String) throws -> DecodedManifest {
        try CharacterManifest.decode(manifestData(name))
    }

    static func manifest(_ name: String) throws -> CharacterManifest {
        try decoded(name).manifest
    }

    /// Probes for every image a manifest references, all decoded at `pixelSize` unless overridden.
    static func probes(
        for manifest: CharacterManifest,
        pixelSize: Int = 64,
        overriding overrides: [String: ImageProbe] = [:]
    ) -> [String: ImageProbe] {
        var probes: [String: ImageProbe] = [:]
        for path in manifest.imagePaths(ofClips: manifest.animations.keys) {
            probes[path] = .decoded(pixelWidth: pixelSize, pixelHeight: pixelSize)
        }
        for (path, probe) in overrides { probes[path] = probe }
        return probes
    }

    static func definition(_ name: String) throws -> CharacterDefinition {
        let manifest = try manifest(name)
        return try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
    }

    /// A character with a single looping `walk` clip (default, facing right, mirrorable), 96 × 96 pt like the cat.
    static func walkingDefinition(
        nominalSpeed: Double? = 20,
        frameCount: Int = 8,
        fps: Double = 9,
        anchorX: Double = 0.5,
        footstepFrames: [Int] = [2, 6]
    ) throws -> CharacterDefinition {
        let frames = (0..<frameCount).map { index in
            CharacterManifest.Frame(
                image: "walk/walk_\(index + 1).png", events: footstepFrames.contains(index) ? ["footstep"] : nil)
        }
        let manifest = CharacterManifest(
            id: "walker", displayName: "Walker", defaultAnimation: "walk", defaultFacing: .right,
            canvas: .init(width: 512, height: 512), displaySize: .init(width: 96, height: 96),
            anchor: .init(x: anchorX, y: 0.074),
            animations: ["walk": .init(fps: fps, frames: frames, nominalSpeed: nominalSpeed)])
        return try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
    }

    /// A clip of `frameCount` image frames at `fps`; `events` maps a frame index to its declared events.
    static func clip(
        _ name: String = "clip",
        frameCount: Int,
        fps: Double,
        playback: AnimationClip.Playback = .loop,
        events: [Int: [String]] = [:]
    ) -> AnimationClip {
        clip(name, durations: Array(repeating: 1 / fps, count: frameCount), playback: playback, events: events)
    }

    static func clip(
        _ name: String = "clip",
        durations: [Double],
        playback: AnimationClip.Playback = .loop,
        events: [Int: [String]] = [:]
    ) -> AnimationClip {
        let frames = durations.enumerated().map { index, duration in
            AnimationClip.Frame(
                source: .image("\(name)/\(name)_\(index + 1).png"), duration: duration, events: events[index] ?? [])
        }
        return AnimationClip(name: name, playback: playback, frames: frames)
    }

    /// The repository checkout this test file belongs to (…/Packages/PetScapeKit/Tests/PetScapeCoreTests/Support).
    static let repositoryRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    /// Pixel size from a PNG's IHDR chunk (bytes 16–23, big-endian), or `nil` when the file is not a PNG.
    static func pngPixelSize(at url: URL) -> (width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: url), data.count >= 24 else { return nil }
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard Array(data.prefix(8)) == signature else { return nil }
        func bigEndian(_ offset: Int) -> Int {
            data[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
        }
        return (bigEndian(16), bigEndian(20))
    }
}
