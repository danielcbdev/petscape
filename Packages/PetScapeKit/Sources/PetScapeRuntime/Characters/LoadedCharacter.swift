import PetScapeCore
import PetScapeRendering

/// A character ready to animate and render: its resolved definition and the decoded frames of every clip.
///
/// When loading fails this is the placeholder character (`failure` says why), so callers never deal with a
/// missing character (FR-15).
public struct LoadedCharacter: Sendable {
    public let definition: CharacterDefinition
    /// Decoded frame pixel size (the cache key used for every frame of this character).
    public let pixelSize: Int
    /// Decoded frames by clip name, in clip frame order.
    public let frames: [String: [FrameImage]]
    /// Non-fatal findings: clip errors (those clips fall back) and warnings.
    public let issues: [ManifestIssue]
    /// Why the real pack could not be used; `nil` when it loaded.
    public let failure: CharacterLoadError?
    /// Decoded pixel bytes held for this character.
    public let decodedByteCount: Int

    public init(
        definition: CharacterDefinition,
        pixelSize: Int,
        frames: [String: [FrameImage]],
        issues: [ManifestIssue] = [],
        failure: CharacterLoadError? = nil,
        decodedByteCount: Int
    ) {
        self.definition = definition
        self.pixelSize = pixelSize
        self.frames = frames
        self.issues = issues
        self.failure = failure
        self.decodedByteCount = decodedByteCount
    }

    public var isPlaceholder: Bool { failure != nil }

    /// Loaded, but some clips are invalid and use their fallbacks.
    public var isDegraded: Bool { failure == nil && issues.contains { $0.severity == .error } }

    /// The image for a frame chosen by `AnimationController`, or `nil` for an out-of-range reference.
    public func frame(_ reference: AnimationFrameRef) -> FrameImage? {
        guard let clipFrames = frames[reference.clip], clipFrames.indices.contains(reference.frameIndex) else {
            return nil
        }
        return clipFrames[reference.frameIndex]
    }
}
