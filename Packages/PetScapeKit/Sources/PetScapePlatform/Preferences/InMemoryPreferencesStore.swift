import PetScapeCore

/// `PreferencesStore` that keeps values in memory only (tests, previews).
public final class InMemoryPreferencesStore: PreferencesStore {
    public var isPaused: Bool
    public var isHidden: Bool
    public var dockOffsetAdjustment: Double {
        didSet { dockOffsetAdjustment = DockGeometryEstimator.clampedOffset(dockOffsetAdjustment) }
    }

    public init(isPaused: Bool = false, isHidden: Bool = false, dockOffsetAdjustment: Double = 0) {
        self.isPaused = isPaused
        self.isHidden = isHidden
        self.dockOffsetAdjustment = DockGeometryEstimator.clampedOffset(dockOffsetAdjustment)
    }
}
