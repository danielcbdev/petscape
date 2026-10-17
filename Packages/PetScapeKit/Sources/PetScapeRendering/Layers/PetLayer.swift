import AppKit
import PetScapeCore
import QuartzCore

/// One pet on screen (ADR-0015): a `CALayer` whose contents are the current frame image, with explicit bounds
/// from the manifest `displaySize` (never the image pixel size), the clip anchor as `anchorPoint` (the contact
/// point) and mirroring as a horizontal flip around that anchor. Implicit animations are disabled: every
/// change is discrete and comes from the simulation.
public final class PetLayer {
    public let layer = CALayer()
    private var applied: PetRenderState?
    private var appliedPosition: CGPoint?
    private var appliedImage: CGImage?

    public init() {
        layer.contentsGravity = .resize
        layer.minificationFilter = .linear
        layer.magnificationFilter = .linear
        layer.isOpaque = false
        layer.actions = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "transform": NSNull(),
            "anchorPoint": NSNull(), "hidden": NSNull(), "contentsScale": NSNull(),
        ]
    }

    /// Shows `state` with its contact point at `overlayPosition` (overlay-local points). Only properties that
    /// changed are written. Call inside a transaction with actions disabled (`PetRenderer` does).
    public func apply(_ state: PetRenderState, overlayPosition: CGPoint, image: CGImage?) {
        let previous = applied
        if previous?.isVisible != state.isVisible { layer.isHidden = !state.isVisible }
        if previous?.size != state.size { layer.bounds = CGRect(origin: .zero, size: state.size) }
        if previous?.frame.anchor != state.frame.anchor {
            layer.anchorPoint = CGPoint(x: state.frame.anchor.x, y: state.frame.anchor.y)
        }
        if previous?.frame.mirrored != state.frame.mirrored {
            layer.setAffineTransform(state.frame.mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
        }
        if appliedPosition != overlayPosition { layer.position = overlayPosition }
        if appliedImage !== image { layer.contents = image }
        applied = state
        appliedPosition = overlayPosition
        appliedImage = image
    }
}
