import CoreGraphics
import Foundation

/// Everything the renderer and the hit tester need for one frame (data-flow.md: snapshots are complete).
public struct RenderSnapshot: Equatable, Sendable {
    public var pets: [PetRenderState]

    public init(pets: [PetRenderState] = []) {
        self.pets = pets
    }

    /// Whether any visible pet moves or animates, i.e. frames are worth rendering (T5.7).
    public var isAnimating: Bool { pets.contains { $0.isVisible } }
}

/// How one pet is drawn: canonical global contact point, size in points and the frame to show.
public struct PetRenderState: Equatable, Sendable {
    public var id: PetID
    public var characterID: CharacterID
    /// Contact point (layer `position`, before the global → overlay-local conversion).
    public var position: CGPoint
    /// Layer bounds size in points: manifest `displaySize` × user scale.
    public var size: CGSize
    /// Clip, frame, mirroring and anchor (layer `anchorPoint`).
    public var frame: AnimationFrameRef
    /// `false` while the pet is not placed on a surface.
    public var isVisible: Bool

    public init(
        id: PetID, characterID: CharacterID, position: CGPoint, size: CGSize, frame: AnimationFrameRef, isVisible: Bool
    ) {
        self.id = id
        self.characterID = characterID
        self.position = position
        self.size = size
        self.frame = frame
        self.isVisible = isVisible
    }

    /// The global rectangle the sprite covers. Mirroring flips the layer around its anchor, so a mirrored
    /// sprite extends `(1 − anchor.x) × width` to the left of the contact point instead of `anchor.x × width`.
    public var spriteRect: CGRect {
        let anchorX = CGFloat(frame.mirrored ? 1 - frame.anchor.x : frame.anchor.x)
        return CGRect(
            x: position.x - anchorX * size.width, y: position.y - CGFloat(frame.anchor.y) * size.height,
            width: size.width, height: size.height)
    }
}
