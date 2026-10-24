import CoreGraphics
import Foundation

enum WindowExcursionPhase: Equatable, Sendable {
    case approachingWindowSide(SurfaceID)
    case jumpingToSide(SurfaceID)
    case climbing(SurfaceID)
    case walkingOnTop(String, WallSide)
    case returningToDock(String, WallSide)
}

/// One pet: identity, placement, state and animation (pet-engine.md#data-model). A value; only `PetWorld`
/// changes it.
///
/// Physical state and autonomous activity execution are world-owned.
public struct Pet: Sendable {
    public let id: PetID
    /// Contact point (paws) in canonical global space.
    public internal(set) var position: CGPoint
    /// Finite velocity in canonical points/s.
    public internal(set) var velocity: CGVector = .zero
    var specialBehaviorDuration = 0.0
    var pendingDockCleanup = false
    var flightOrigin: FlightOrigin = .fall
    var airborneElapsed: Double = 0
    var jumpPlan: JumpPlan?
    var jumpSource: Surface?
    var windowClimbPlan: WindowClimbPlan?
    var windowExcursionPhase: WindowExcursionPhase?
    public internal(set) var resumeActivity: ResumeActivity = .walking
    var lastJumpLaunchTime: Double?
    var jumpRequestID = 0
    var consumedJumpID = 0
    var contactGeometry: ContactGeometry?
    private let visualAnchorX: Double
    /// `nil` while not placed (no surface yet, or during recovery).
    public internal(set) var attachment: SurfaceAttachment?
    public internal(set) var facing: Facing
    public internal(set) var state: PetState
    /// Simulation time spent in `state`.
    public internal(set) var stateElapsed: Double
    public internal(set) var animation: AnimationController
    /// User display scale (1 = the manifest `displaySize`).
    public internal(set) var scale: Double
    public internal(set) var needs = Needs()
    public internal(set) var personality: Personality
    public internal(set) var activity: Activity?
    public internal(set) var activityDecisionCount = 0
    var activityDeadline: Double = 0
    var activityDuration: Double = 0
    var previousActivity: Activity?
    var activityRepetitions = 0
    var activityCooldowns: [Activity: Double] = [:]
    /// Shared budget across consecutive autonomous rest/expression states.
    var stationaryElapsed: Double = 0
    var noProgressElapsed: Double = 0
    var progressPosition: CGPoint = .zero
    var cursorInterest = CursorInterest()
    var cursorEvaluationElapsed = 0.0
    var cursorSavedActivity: Activity?
    var cursorSavedActivityRemaining = 0.0
    var interactionID: InteractionID?
    var interactionIsHeld = false
    var heldPickupPresentationActive = false
    var interactionTarget: CGPoint?
    var interactionSavedState: PetState?
    var interactionSavedStateElapsed = 0.0
    var interactionSavedActivity: Activity?
    var interactionSavedActivityRemaining = 0.0
    var clickCooldownUntil = 0.0
    var clickSavedState: PetState?
    var clickSavedStateElapsed = 0.0
    var clickSavedActivity: Activity?
    var clickSavedActivityRemaining = 0.0

    init(id: PetID, definition: CharacterDefinition, scale: Double) {
        self.id = id
        personality = Personality(definition.personality)
        position = .zero
        attachment = nil
        facing = definition.defaultFacing
        state = .spawning
        stateElapsed = 0
        animation = AnimationController(definition: definition)
        self.scale = scale
        let walk = definition.clip(named: BehaviorTuning.walkClip)
        visualAnchorX = walk.anchor.x
        contactGeometry = ContactGeometry(
            displaySize: CGSize(width: definition.displaySize.width, height: definition.displaySize.height),
            scale: scale)
    }

    public var characterID: CharacterID { animation.definition.id }

    /// On-screen size of the sprite in points (layer bounds; never the image pixel size).
    public var size: CGSize {
        let displaySize = animation.definition.displaySize
        return CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
    }

    /// How far the sprite reaches sideways from the contact point, for either facing: the larger side of the
    /// anchor. Equals half the sprite width for a centered anchor (state-machines.md: edge margin).
    public var edgeMargin: CGFloat {
        let anchorX = visualAnchorX
        return CGFloat(max(anchorX, 1 - anchorX)) * size.width
    }
}
