import CoreGraphics
import Foundation

/// One pet: identity, placement, state and animation (pet-engine.md#data-model). A value; only `PetWorld`
/// changes it.
///
/// MVP subset of the target model: no velocity (walking moves along the surface), needs, personality or
/// cooldowns yet — they arrive with physics (M7) and behaviors (M9).
public struct Pet: Sendable {
    public let id: PetID
    /// Contact point (paws) in canonical global space.
    public internal(set) var position: CGPoint
    /// `nil` while not placed (no surface yet, or during recovery).
    public internal(set) var attachment: SurfaceAttachment?
    public internal(set) var facing: Facing
    public internal(set) var state: PetState
    /// Simulation time spent in `state`.
    public internal(set) var stateElapsed: Double
    public internal(set) var animation: AnimationController
    /// User display scale (1 = the manifest `displaySize`).
    public let scale: Double

    init(id: PetID, definition: CharacterDefinition, scale: Double) {
        self.id = id
        position = .zero
        attachment = nil
        facing = definition.defaultFacing
        state = .spawning
        stateElapsed = 0
        animation = AnimationController(definition: definition)
        self.scale = scale
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
        let anchorX = animation.player.clip.anchor.x
        return CGFloat(max(anchorX, 1 - anchorX)) * size.width
    }
}
