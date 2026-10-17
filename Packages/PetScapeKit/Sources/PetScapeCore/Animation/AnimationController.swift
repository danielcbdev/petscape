/// Per-pet animation state: which clip plays, at which priority, facing which way.
///
/// Resolves requests through the character's fallbacks, applies priority and interruptibility, chains
/// `next` after `once` clips, and picks direction variants or mirroring.
///
/// Acceptance rule for a request with priority `p`:
/// - the current clip finished (a `once` clip holding its last frame) → accepted;
/// - the current clip is `interruptible: false` → accepted only if `p >= AnimationRequest.criticalPriority`;
/// - otherwise → accepted if `p >=` the current priority.
public struct AnimationController: Sendable {
    /// Upper bound of `next` hops in one step, so a chain of very short `once` clips cannot spin.
    static let maxChainedClipsPerStep = 8

    public let definition: CharacterDefinition
    public private(set) var player: AnimationPlayer
    /// Clip name as requested (before fallback/variant resolution); re-resolved when the facing changes.
    public private(set) var requestedClip: String
    public private(set) var priority: Int
    public private(set) var facing: Facing
    public private(set) var isMirrored: Bool

    /// Starts the character's default clip at priority 0.
    public init(definition: CharacterDefinition, facing: Facing? = nil, rate: Double = 1) {
        let facing = facing ?? definition.defaultFacing
        let selection = definition.clip(named: definition.defaultClipName, facing: facing)
        self.definition = definition
        self.player = AnimationPlayer(clip: selection.clip, rate: rate)
        self.requestedClip = definition.defaultClipName
        self.priority = 0
        self.facing = facing
        self.isMirrored = selection.mirrored
    }

    /// Playback speed multiplier (e.g. walk speed setting), kept across clip changes.
    public var rate: Double {
        get { player.rate }
        set { player.rate = newValue }
    }

    /// What the renderer should show now.
    public var currentFrame: AnimationFrameRef {
        AnimationFrameRef(
            clip: player.clip.name, frameIndex: player.frameIndex, mirrored: isMirrored, anchor: player.clip.anchor)
    }

    /// Applies `request` if the acceptance rule allows it; returns whether it was accepted.
    @discardableResult
    public mutating func request(_ request: AnimationRequest) -> Bool {
        guard canBeInterrupted(byPriority: request.priority) else { return false }
        if definition.clips[request.clip] == nil {
            let resolved = definition.resolvedClipName(for: request.clip)
            Log.animation.debug(
                "Clip '\(request.clip, privacy: .public)' resolves to '\(resolved, privacy: .public)'")
        }
        let selection = definition.clip(named: request.clip, facing: facing)
        requestedClip = request.clip
        priority = request.priority
        isMirrored = selection.mirrored
        if selection.clip.name != player.clip.name {
            start(selection.clip)
        } else if request.restart || player.isFinished {
            player.restart()
        }
        return true
    }

    /// Turns the pet. Switches to a direction variant when the clip has one (keeping the frame position),
    /// otherwise only the mirroring changes.
    public mutating func setFacing(_ newFacing: Facing) {
        guard newFacing != facing else { return }
        facing = newFacing
        let selection = definition.clip(named: requestedClip, facing: newFacing)
        isMirrored = selection.mirrored
        guard selection.clip.name != player.clip.name else { return }
        let frameIndex = player.frameIndex
        start(selection.clip)
        player.jump(toFrame: frameIndex)
    }

    /// Advances by `dt` seconds of simulation time and appends events in order (see `AnimationPlayer`).
    public mutating func advance(by dt: Double, into events: inout [AnimationEvent]) {
        player.advance(by: dt, into: &events)
        var hops = 0
        while player.isFinished, let next = player.clip.next, hops < Self.maxChainedClipsPerStep {
            hops += 1
            let leftover = player.unusedTime
            requestedClip = next
            let selection = definition.clip(named: next, facing: facing)
            isMirrored = selection.mirrored
            start(selection.clip)
            player.advance(by: leftover, into: &events)
        }
    }

    /// Convenience for tests and non-hot paths.
    public mutating func advance(by dt: Double) -> [AnimationEvent] {
        var events: [AnimationEvent] = []
        advance(by: dt, into: &events)
        return events
    }

    private func canBeInterrupted(byPriority newPriority: Int) -> Bool {
        if player.isFinished { return true }
        if !player.clip.interruptible { return newPriority >= AnimationRequest.criticalPriority }
        return newPriority >= priority
    }

    private mutating func start(_ clip: AnimationClip) {
        player = AnimationPlayer(clip: clip, rate: player.rate)
    }
}

/// The frame the renderer shows for a pet: clip, frame, mirroring and contact point.
public struct AnimationFrameRef: Equatable, Sendable {
    public var clip: String
    public var frameIndex: Int
    public var mirrored: Bool
    /// Normalized contact point of the clip (layer `anchorPoint`).
    public var anchor: AnimationClip.Point

    public init(clip: String, frameIndex: Int, mirrored: Bool, anchor: AnimationClip.Point) {
        self.clip = clip
        self.frameIndex = frameIndex
        self.mirrored = mirrored
        self.anchor = anchor
    }
}
