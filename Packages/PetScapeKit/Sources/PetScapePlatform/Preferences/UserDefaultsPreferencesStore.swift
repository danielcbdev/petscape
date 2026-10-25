import Foundation
import PetScapeCore

/// `PreferencesStore` backed by `UserDefaults` with namespaced (`petscape.`), versioned keys.
public final class UserDefaultsPreferencesStore: PreferencesStore {
    /// Stored keys: part of the persistence contract, change only with a migration.
    public enum Key {
        public static let selectedCharacterID = "petscape.selectedCharacterID"
        public static let activeCharacterIDs = "petscape.activeCharacterIDs"
        public static let version = "petscape.preferencesVersion"
        public static let scale = "petscape.scale"
        public static let speed = "petscape.speed"
        public static let autonomy = "petscape.autonomy"
        public static let jumps = "petscape.jumps"
        public static let rest = "petscape.rest"
        public static let expressions = "petscape.expressions"
        public static let isPaused = "petscape.isPaused"
        public static let isHidden = "petscape.isHidden"
        /// Added in M6 without a version bump: absent means 0, the default.
        public static let dockOffsetAdjustment = "petscape.dockOffsetAdjustment"
        public static let cursorReactions = "petscape.cursorReactions"
        public static let directInteraction = "petscape.directInteraction"
        public static let musicDancing = "petscape.musicDancing"
        public static let windowInteraction = "petscape.windowInteraction"
    }

    /// Bump with a migration in `migrate()` when keys or meanings change.
    public static let currentVersion = 4

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrate()
    }

    /// Roster preference. `nil` is distinct from `[]` so an intentionally empty roster stays empty on relaunch.
    public var activeCharacterIDs: [String]? {
        get {
            guard defaults.object(forKey: Key.activeCharacterIDs) != nil else { return nil }
            return (defaults.array(forKey: Key.activeCharacterIDs) as? [String]) ?? [""]
        }
        set { defaults.set(newValue, forKey: Key.activeCharacterIDs) }
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

    public var isWindowInteractionEnabled: Bool {
        get { defaults.bool(forKey: Key.windowInteraction) }
        set { defaults.set(newValue, forKey: Key.windowInteraction) }
    }

    public var isMusicDancingEnabled: Bool {
        get { defaults.bool(forKey: Key.musicDancing) }
        set { defaults.set(newValue, forKey: Key.musicDancing) }
    }

    public var petSettings: PetSettings {
        get {
            PetSettings(
                scale: defaults.object(forKey: Key.scale) == nil ? 1 : defaults.double(forKey: Key.scale),
                speed: defaults.object(forKey: Key.speed) == nil
                    ? PetSettings.defaultSpeed : defaults.double(forKey: Key.speed),
                behavior: AutonomySettings(
                    isEnabled: enabled(Key.autonomy), jumpsEnabled: enabled(Key.jumps),
                    restEnabled: enabled(Key.rest), expressionsEnabled: enabled(Key.expressions)),
                interaction: InteractionSettings(
                    cursorReactionsEnabled: enabled(Key.cursorReactions),
                    directInteractionEnabled: enabled(Key.directInteraction)))
        }
        set {
            defaults.set(newValue.scale, forKey: Key.scale)
            defaults.set(newValue.speed, forKey: Key.speed)
            defaults.set(newValue.behavior.isEnabled, forKey: Key.autonomy)
            defaults.set(newValue.behavior.jumpsEnabled, forKey: Key.jumps)
            defaults.set(newValue.behavior.restEnabled, forKey: Key.rest)
            defaults.set(newValue.behavior.expressionsEnabled, forKey: Key.expressions)
            defaults.set(newValue.interaction.cursorReactionsEnabled, forKey: Key.cursorReactions)
            defaults.set(newValue.interaction.directInteractionEnabled, forKey: Key.directInteraction)
        }
    }

    public func restoreDefaults() {
        for key in [
            Key.isPaused, Key.isHidden, Key.dockOffsetAdjustment,
            Key.scale, Key.speed, Key.autonomy, Key.jumps, Key.rest, Key.expressions,
            Key.cursorReactions, Key.directInteraction,
            Key.windowInteraction, Key.musicDancing,
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    private func enabled(_ key: String) -> Bool {
        defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
    }

    /// V2 adds autonomy, V3 interaction and V4 roster keys. V4 copies the legacy selected ID once.
    /// An unknown newer schema is retained, including its version and unknown keys.
    private func migrate() {
        let stored = defaults.integer(forKey: Key.version)
        if stored < Self.currentVersion {
            if defaults.object(forKey: Key.activeCharacterIDs) == nil,
                let selectedID = defaults.string(forKey: Key.selectedCharacterID)
            {
                defaults.set([selectedID], forKey: Key.activeCharacterIDs)
            }
            defaults.removeObject(forKey: Key.selectedCharacterID)
            Log.app.info(
                "Preferences version \(stored, privacy: .public) → \(Self.currentVersion, privacy: .public)")
            defaults.set(Self.currentVersion, forKey: Key.version)
        }
    }
}
