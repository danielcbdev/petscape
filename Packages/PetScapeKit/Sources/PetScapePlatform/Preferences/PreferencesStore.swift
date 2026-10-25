import PetScapeCore

/// The user's persisted choices (FR-18, data-flow.md#persistence). M9: pet settings, pause, hide and the Dock offset.
public protocol PreferencesStore: AnyObject {
    /// Persisted manifest IDs in roster order. `nil` means first launch; an empty array is an intentional empty roster.
    var activeCharacterIDs: [String]? { get set }
    var petSettings: PetSettings { get set }
    /// Resets only the keys owned by this version of PetScape.
    func restoreDefaults()

    var isPaused: Bool { get set }
    var isHidden: Bool { get set }
    /// Points added to the estimated Dock top (surface-detection.md), kept within
    /// `DockGeometryEstimator.offsetAdjustmentRange`; 0 by default (PoC E3).
    var dockOffsetAdjustment: Double { get set }
    /// Optional system-audio detection. Absence defaults off; manual dance does not use it.
    var isMusicDancingEnabled: Bool { get set }
    /// Explicit opt-in for window tracking; absent values must default to false.
    var isWindowInteractionEnabled: Bool { get set }
}

extension PreferencesStore {
    /// Pause and hide as one value, to seed the run state at launch.
    public var userIntent: UserIntent {
        UserIntent(isPaused: isPaused, isHidden: isHidden)
    }
}
