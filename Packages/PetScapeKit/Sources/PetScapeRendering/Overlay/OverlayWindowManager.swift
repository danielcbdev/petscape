import AppKit
import PetScapeCore

/// Creates, re-lays out and removes one `OverlayPanel` per hosting screen (macos-integration.md;
/// MVP: only the screen chosen by the runtime). Owns the panels' visibility, pass-through flag and
/// occlusion observation.
public final class OverlayWindowManager {
    /// Called with the screen and the event while that overlay accepts the mouse.
    public var onMouseEvent: ((ScreenID, OverlayMouseEvent) -> Void)?
    /// Called when the overlays become visible to the user or stop being so (occlusion state).
    public var onOcclusionChange: ((_ isVisible: Bool) -> Void)?

    private let notificationCenter: NotificationCenter
    private var panels: [ScreenID: OverlayPanel] = [:]
    private var occlusionObservers: [ScreenID: any NSObjectProtocol] = [:]
    private var lastReportedVisibility: Bool?

    public private(set) var isVisible = false
    public private(set) var ignoresMouseEvents = true

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    public var screenIDs: Set<ScreenID> { Set(panels.keys) }

    public func panel(for id: ScreenID) -> OverlayPanel? { panels[id] }

    public func contentView(for id: ScreenID) -> OverlayContentView? {
        panels[id]?.contentView as? OverlayContentView
    }

    /// Makes the set of panels match `hosting` (IDs not in `screens` are ignored): new screens get a
    /// panel, existing ones follow their screen's frame, others are closed.
    public func update(screens: [ScreenDescriptor], hosting: Set<ScreenID>) {
        let wanted = Dictionary(uniqueKeysWithValues: screens.filter { hosting.contains($0.id) }.map { ($0.id, $0) })
        for id in panels.keys where wanted[id] == nil {
            removePanel(id)
        }
        for (id, screen) in wanted {
            if let panel = panels[id] {
                if panel.frame != screen.frame {
                    panel.setFrame(screen.frame, display: false)
                    Log.overlay.notice(
                        "Overlay \(id, privacy: .public) re-laid out: frame=\(String(describing: panel.frame), privacy: .public)"
                    )
                }
            } else {
                addPanel(for: screen)
            }
        }
    }

    /// Orders all overlays in (front, without activating the app) or out.
    public func setVisible(_ visible: Bool) {
        isVisible = visible
        for panel in panels.values { apply(visibility: visible, to: panel) }
    }

    public func setIgnoresMouseEvents(_ ignores: Bool) {
        ignoresMouseEvents = ignores
        for panel in panels.values { panel.ignoresMouseEvents = ignores }
    }

    /// Closes every panel and removes observers (FR-13).
    public func removeAll() {
        for id in panels.keys { removePanel(id) }
    }

    // MARK: Private

    private func addPanel(for screen: ScreenDescriptor) {
        let panel = OverlayPanel(frame: screen.frame)
        let view = OverlayContentView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]
        let id = screen.id
        view.onMouseEvent = { [weak self] event in self?.onMouseEvent?(id, event) }
        panel.contentView = view
        panel.ignoresMouseEvents = ignoresMouseEvents
        panels[id] = panel
        occlusionObservers[id] = notificationCenter.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportOcclusion() }
        }
        apply(visibility: isVisible, to: panel)
        Log.overlay.notice(
            "Overlay \(id, privacy: .public) created: frame=\(String(describing: panel.frame), privacy: .public) level=\(panel.level.rawValue, privacy: .public)"
        )
    }

    private func removePanel(_ id: ScreenID) {
        if let observer = occlusionObservers.removeValue(forKey: id) { notificationCenter.removeObserver(observer) }
        guard let panel = panels.removeValue(forKey: id) else { return }
        (panel.contentView as? OverlayContentView)?.onMouseEvent = nil
        panel.orderOut(nil)
        panel.close()
        Log.overlay.notice("Overlay \(id, privacy: .public) removed")
    }

    private func apply(visibility: Bool, to panel: OverlayPanel) {
        if visibility {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func reportOcclusion() {
        let visible = panels.values.contains { $0.occlusionState.contains(.visible) }
        guard visible != lastReportedVisibility else { return }
        lastReportedVisibility = visible
        Log.overlay.info("Overlay occlusion: visible=\(visible, privacy: .public)")
        onOcclusionChange?(visible)
    }
}
