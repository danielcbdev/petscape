import CoreGraphics
import PetScapeCore

/// The pet's walkway from the Dock (T6.2, surface-detection.md#providers): `.dockTop` for a bottom Dock, the
/// screen bottom otherwise.
///
/// Fed with the screens `ScreenProvider` reports. Those are re-read after every
/// `didChangeScreenParametersNotification`, which PoC E3 showed is posted for every Dock resize, move and
/// auto-hide toggle, and again when a suspension ends (the coordinator's fallback re-read) — so this provider
/// owns no observer and never polls. The heuristic itself is Core's `DockGeometryEstimator`; this keeps the
/// current estimate and offset and logs their changes.
public final class DockSurfaceProvider {
    public private(set) var estimate = DockEstimate.hiddenOrUnknown
    /// The current walkway; `nil` without screens.
    public private(set) var surface: Surface?

    /// Points added to the estimated Dock top (`dockOffsetAdjustment`), clamped to
    /// `DockGeometryEstimator.offsetAdjustmentRange`.
    public var offsetAdjustment: Double {
        didSet {
            offsetAdjustment = DockGeometryEstimator.clampedOffset(offsetAdjustment)
            if offsetAdjustment != oldValue { recomputeSurface() }
        }
    }

    private var screens: [ScreenDescriptor] = []

    public init(offsetAdjustment: Double = 0) {
        self.offsetAdjustment = DockGeometryEstimator.clampedOffset(offsetAdjustment)
    }

    /// The walkway as a surface set for `PetWorld` (empty without screens).
    public var surfaces: [Surface] { surface.map { [$0] } ?? [] }

    /// The screen that hosts the overlay with the pet: the Dock's screen, or the primary screen when the Dock is
    /// hidden or unknown (where the fallback surface is).
    public var hostScreenID: ScreenID? {
        estimate.screenID ?? (screens.first { $0.isPrimary } ?? screens.first)?.id
    }

    /// Re-estimates the Dock for `screens`.
    public func update(screens: [ScreenDescriptor]) {
        self.screens = screens
        let next = DockGeometryEstimator.estimate(screens: screens)
        if next != estimate {
            Log.dock.notice("Dock estimate: \(next.description, privacy: .public)")
            estimate = next
        }
        recomputeSurface()
    }

    private func recomputeSurface() {
        let next = DockGeometryEstimator.surface(for: estimate, screens: screens, offsetAdjustment: offsetAdjustment)
        guard next != surface else { return }
        surface = next
        Signposts.event(Signposts.Event.surfaceChanged)
        if let next {
            Log.dock.notice(
                "Walkway \(next.id, privacy: .public) (\(next.kind.rawValue, privacy: .public)) at y=\(next.y, format: .fixed(precision: 1), privacy: .public), x \(next.minX, format: .fixed(precision: 1), privacy: .public)…\(next.maxX, format: .fixed(precision: 1), privacy: .public), offset \(self.offsetAdjustment, format: .fixed(precision: 1), privacy: .public) pt"
            )
        } else {
            Log.dock.notice("Walkway: none (no screens)")
        }
    }
}
