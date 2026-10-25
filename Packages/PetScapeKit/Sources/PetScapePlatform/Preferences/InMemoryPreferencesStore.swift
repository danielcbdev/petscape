import PetScapeCore

/// `PreferencesStore` that keeps values in memory only (tests, previews).
public final class InMemoryPreferencesStore: PreferencesStore {
    public var activeCharacterIDs: [String]?
    public var petSettings: PetSettings
    public var isPaused: Bool
    public var isHidden: Bool
    public var isMusicDancingEnabled = false
    public var isWindowInteractionEnabled: Bool
    public var dockOffsetAdjustment: Double {
        didSet { dockOffsetAdjustment = DockGeometryEstimator.clampedOffset(dockOffsetAdjustment) }
    }

    public init(
        isPaused: Bool = false, isHidden: Bool = false, isWindowInteractionEnabled: Bool = false,
        dockOffsetAdjustment: Double = 0,
        petSettings: PetSettings = PetSettings()
    ) {
        self.petSettings = petSettings
        self.isPaused = isPaused
        self.isHidden = isHidden
        self.isWindowInteractionEnabled = isWindowInteractionEnabled
        self.dockOffsetAdjustment = DockGeometryEstimator.clampedOffset(dockOffsetAdjustment)
    }
    public func restoreDefaults() {
        isPaused = false
        isHidden = false
        isWindowInteractionEnabled = false
        isMusicDancingEnabled = false
        dockOffsetAdjustment = 0
        petSettings = PetSettings()
    }
}
