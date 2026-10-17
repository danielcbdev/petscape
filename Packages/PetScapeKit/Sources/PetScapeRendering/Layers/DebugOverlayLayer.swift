#if DEBUG
    import AppKit
    import QuartzCore

    /// DEBUG-only visuals of an overlay (debugging.md#debug-menu): overlay outline, pass-through tint and the
    /// walkway line (where the paws should be).
    /// Never affects the simulation.
    final class DebugOverlayLayer {
        /// Container added to the overlay view's layer; sized to the overlay bounds.
        let layer = CALayer()
        private let outline = CAShapeLayer()
        private let tint = CALayer()
        private let walkway = CALayer()

        var showsBounds = false { didSet { update() } }
        var showsPassthroughState = false { didSet { update() } }
        var isInteractive = false { didSet { if isInteractive != oldValue { update() } } }
        /// Overlay-local y of the walkway; `nil` hides the line.
        var walkwayY: CGFloat? { didSet { if walkwayY != oldValue { update() } } }

        init() {
            outline.fillColor = nil
            outline.strokeColor = NSColor.systemRed.cgColor
            outline.lineWidth = 2
            tint.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.08).cgColor
            walkway.backgroundColor = NSColor.systemGreen.cgColor
            for each in [layer, outline, tint, walkway] {
                // Discrete changes only (ADR-0015): no implicit animations.
                each.actions = [
                    "position": NSNull(), "bounds": NSNull(), "frame": NSNull(), "hidden": NSNull(),
                    "path": NSNull(), "backgroundColor": NSNull(), "borderColor": NSNull(),
                    "sublayers": NSNull(), "contents": NSNull(),
                ]
            }
            layer.addSublayer(tint)
            layer.addSublayer(outline)
            layer.addSublayer(walkway)
            update()
        }

        func layout(in bounds: CGRect) {
            layer.frame = bounds
            update()
        }

        private func update() {
            let bounds = layer.bounds
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            tint.frame = bounds
            tint.isHidden = !(showsPassthroughState && isInteractive)
            outline.frame = bounds
            outline.path = CGPath(rect: bounds.insetBy(dx: 1, dy: 1), transform: nil)
            outline.isHidden = !showsBounds
            // 1 pt tall, its top edge on the walkway: paws resting on the surface touch the line's top.
            walkway.frame = CGRect(x: bounds.minX, y: (walkwayY ?? 0) - 1, width: bounds.width, height: 1)
            walkway.isHidden = walkwayY == nil
            CATransaction.commit()
        }
    }
#endif
