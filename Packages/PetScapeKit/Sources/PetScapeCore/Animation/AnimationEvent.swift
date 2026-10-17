/// Something that happened while an `AnimationPlayer` advanced, in playback order.
public struct AnimationEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// A name declared on the entered frame in `character.json` (e.g. `footstep`, `takeoff`).
        case frame(String)
        /// A `loop` clip wrapped to frame 0, or a `pingPong` clip finished a round trip.
        case loopCompleted
        /// A `once` clip reached the end of its last frame (it now holds that frame).
        case finished
    }

    public var clip: String
    /// The frame the event belongs to (the entered frame, or the last frame for `finished`).
    public var frameIndex: Int
    public var kind: Kind

    public init(clip: String, frameIndex: Int, kind: Kind) {
        self.clip = clip
        self.frameIndex = frameIndex
        self.kind = kind
    }
}
