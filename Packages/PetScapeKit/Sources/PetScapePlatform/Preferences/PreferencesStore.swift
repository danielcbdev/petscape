import PetScapeCore

/// The user's persisted choices (FR-18, data-flow.md#persistence). MVP: pause, hide and the Dock offset.
public protocol PreferencesStore: AnyObject {
    var isPaused: Bool { get set }
    var isHidden: Bool { get set }
    /// Points added to the estimated Dock top (surface-detection.md), kept within
    /// `DockGeometryEstimator.offsetAdjustmentRange`; 0 by default (PoC E3).
    var dockOffsetAdjustment: Double { get set }
}

extension PreferencesStore {
    /// Pause and hide as one value, to seed the run state at launch.
    public var userIntent: UserIntent {
        UserIntent(isPaused: isPaused, isHidden: isHidden)
    }
}
