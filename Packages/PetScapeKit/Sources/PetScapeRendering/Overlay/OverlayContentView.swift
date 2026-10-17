import AppKit
import PetScapeCore
import QuartzCore

/// Content of an `OverlayPanel`: a layer-backed, non-flipped, clear view. Overlay-local coordinates
/// (= window-local points, origin = screen origin, y up) are used for its layers (coordinate-system.md).
/// While pass-through is off it receives the mouse and forwards it through `onMouseEvent`.
public final class OverlayContentView: NSView {
    public var onMouseEvent: ((OverlayMouseEvent) -> Void)?
    /// Parent of the pet layers; its coordinates are overlay-local (same bounds as the view).
    public let petLayerHost = CALayer()

    #if DEBUG
        private let debugLayer = DebugOverlayLayer()
    #endif

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        // `wantsLayer` created the backing layer. Invariant: a layer-backed view always has a layer.
        let layer = self.layer!
        layer.backgroundColor = .clear
        layer.isOpaque = false
        setAccessibilityElement(false)
        petLayerHost.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "sublayers": NSNull()]
        petLayerHost.frame = layer.bounds
        layer.addSublayer(petLayerHost)
        #if DEBUG
            debugLayer.layout(in: layer.bounds)
            layer.addSublayer(debugLayer.layer)
        #endif
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public var isFlipped: Bool { false }

    // The overlay is never key: take the first click instead of treating it as an activation click.
    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override public func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        petLayerHost.frame = bounds
        #if DEBUG
            debugLayer.layout(in: bounds)
        #endif
        CATransaction.commit()
    }

    // Mouse-moved events reach a non-key window only through a tracking area.
    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
            NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override public func mouseMoved(with event: NSEvent) { forward(.moved, event) }
    override public func mouseDown(with event: NSEvent) { forward(.down, event) }
    override public func mouseDragged(with event: NSEvent) { forward(.dragged, event) }
    override public func mouseUp(with event: NSEvent) { forward(.up, event) }

    private func forward(_ kind: OverlayMouseEvent.Kind, _ event: NSEvent) {
        onMouseEvent?(OverlayMouseEvent(kind: kind, location: NSEvent.mouseLocation, timestamp: event.timestamp))
    }

    #if DEBUG
        /// DEBUG menu "Show overlay bounds" (debugging.md).
        public var showsBounds: Bool {
            get { debugLayer.showsBounds }
            set { debugLayer.showsBounds = newValue }
        }

        /// DEBUG menu "Show pass-through state": tint the overlay while it accepts the mouse.
        public var showsPassthroughState: Bool {
            get { debugLayer.showsPassthroughState }
            set { debugLayer.showsPassthroughState = newValue }
        }

        public func setInteractive(_ isInteractive: Bool) {
            debugLayer.isInteractive = isInteractive
        }
    #endif
}
