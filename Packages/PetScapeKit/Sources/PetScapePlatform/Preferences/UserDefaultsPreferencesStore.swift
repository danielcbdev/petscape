import Foundation
import PetScapeCore

/// `PreferencesStore` backed by `UserDefaults` with namespaced (`petscape.`), versioned keys.
public final class UserDefaultsPreferencesStore: PreferencesStore {
    /// Stored keys: part of the persistence contract, change only with a migration.
    public enum Key {
        public static let version = "petscape.preferencesVersion"
        public static let isPaused = "petscape.isPaused"
        public static let isHidden = "petscape.isHidden"
        /// Added in M6 without a version bump: absent means 0, the default.
        public static let dockOffsetAdjustment = "petscape.dockOffsetAdjustment"
    }

    /// Bump with a migration in `migrate()` when keys or meanings change.
    public static let currentVersion = 1

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrate()
    }

    public var isPaused: Bool {
        get { defaults.bool(forKey: Key.isPaused) }
        set { defaults.set(newValue, forKey: Key.isPaused) }
    }

    public var isHidden: Bool {
        get { defaults.bool(forKey: Key.isHidden) }
        set { defaults.set(newValue, forKey: Key.isHidden) }
    }

    /// Clamped on read and write, so a hand-edited value cannot push the Dock surface off screen.
    public var dockOffsetAdjustment: Double {
        get { DockGeometryEstimator.clampedOffset(defaults.double(forKey: Key.dockOffsetAdjustment)) }
        set { defaults.set(DockGeometryEstimator.clampedOffset(newValue), forKey: Key.dockOffsetAdjustment) }
    }

    /// Version 1 is the first: nothing to migrate yet, only record the version.
    private func migrate() {
        let stored = defaults.integer(forKey: Key.version)
        if stored != Self.currentVersion {
            Log.app.info(
                "Preferences version \(stored, privacy: .public) → \(Self.currentVersion, privacy: .public)")
            defaults.set(Self.currentVersion, forKey: Key.version)
        }
    }
}
