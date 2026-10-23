#if DEBUG
    import AppKit
    import PetScapeCore
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
        private let windowSurfaces = CAShapeLayer()

        var showsBounds = false { didSet { update() } }
        var showsPassthroughState = false { didSet { update() } }
        var isInteractive = false { didSet { if isInteractive != oldValue { update() } } }
        /// Overlay-local y of the walkway; `nil` hides the line.
        var walkwayY: CGFloat? { didSet { if walkwayY != oldValue { update() } } }
        var windowSurfaceSegments: [Surface] = [] { didSet { update() } }
        var screenFrame = CGRect.zero { didSet { update() } }
        var showsWindowSurfaces = false { didSet { update() } }

        init() {
            outline.fillColor = nil
            outline.strokeColor = NSColor.systemRed.cgColor
            outline.lineWidth = 2
            tint.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.08).cgColor
            walkway.backgroundColor = NSColor.systemGreen.cgColor
            windowSurfaces.fillColor = nil
            windowSurfaces.strokeColor = NSColor.systemPink.cgColor
            windowSurfaces.lineWidth = 2
            windowSurfaces.lineDashPattern = [4, 3]
            for each in [layer, outline, tint, walkway, windowSurfaces] {
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
            layer.addSublayer(windowSurfaces)
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
            let path = CGMutablePath()
            for surface in windowSurfaceSegments {
                switch surface.kind {
                case .windowTop:
                    let lower = max(surface.minX, screenFrame.minX)
                    let upper = min(surface.maxX, screenFrame.maxX)
                    guard upper > lower, surface.y >= screenFrame.minY, surface.y <= screenFrame.maxY else {
                        continue
                    }
                    let y = surface.y - screenFrame.minY
                    path.move(to: CGPoint(x: lower - screenFrame.minX, y: y))
                    path.addLine(to: CGPoint(x: upper - screenFrame.minX, y: y))
                case .windowLeft, .windowRight:
                    let lower = max(surface.minY, screenFrame.minY)
                    let upper = min(surface.maxY, screenFrame.maxY)
                    guard upper > lower, surface.minX >= screenFrame.minX, surface.minX <= screenFrame.maxX else {
                        continue
                    }
                    let x = surface.minX - screenFrame.minX
                    path.move(to: CGPoint(x: x, y: lower - screenFrame.minY))
                    path.addLine(to: CGPoint(x: x, y: upper - screenFrame.minY))
                default:
                    continue
                }
            }
            windowSurfaces.frame = bounds
            windowSurfaces.path = path
            windowSurfaces.isHidden = !showsWindowSurfaces || windowSurfaceSegments.isEmpty
            CATransaction.commit()
        }
    }
#endif
