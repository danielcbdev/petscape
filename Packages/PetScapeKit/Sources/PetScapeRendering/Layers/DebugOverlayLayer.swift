#if DEBUG
    import AppKit
    import QuartzCore

    /// DEBUG-only visuals of an overlay (debugging.md#debug-menu): overlay outline, pass-through tint and
    /// the M3 test rectangle that stands in for the pet. Never affects the simulation.
    final class DebugOverlayLayer {
        /// Container added to the overlay view's layer; sized to the overlay bounds.
        let layer = CALayer()
        private let outline = CAShapeLayer()
        private let tint = CALayer()
        private let target = CALayer()

        var showsBounds = false { didSet { update() } }
        var showsPassthroughState = false { didSet { update() } }
        var isInteractive = false { didSet { if isInteractive != oldValue { update() } } }
        var targetRect: CGRect? { didSet { update() } }

        init() {
            outline.fillColor = nil
            outline.strokeColor = NSColor.systemRed.cgColor
            outline.lineWidth = 2
            tint.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.08).cgColor
            target.borderWidth = 2
            for each in [layer, outline, tint, target] {
                // Discrete changes only (ADR-0015): no implicit animations.
                each.actions = [
                    "position": NSNull(), "bounds": NSNull(), "frame": NSNull(), "hidden": NSNull(),
                    "path": NSNull(), "backgroundColor": NSNull(), "borderColor": NSNull(),
                    "sublayers": NSNull(), "contents": NSNull(),
                ]
            }
            layer.addSublayer(tint)
            layer.addSublayer(target)
            layer.addSublayer(outline)
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
            if let targetRect {
                target.isHidden = false
                target.frame = targetRect
                let color = isInteractive ? NSColor.systemGreen : NSColor.systemOrange
                target.backgroundColor = color.withAlphaComponent(0.85).cgColor
                target.borderColor = color.shadow(withLevel: 0.4)?.cgColor
            } else {
                target.isHidden = true
            }
            CATransaction.commit()
        }
    }
#endif
