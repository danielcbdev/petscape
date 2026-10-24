import Foundation
import Testing

@testable import PetScapeCore
@testable import PetScapePlatform

/// T5.6: persisted pause/hide (FR-18, AC-18) and T6.3: the Dock offset, with an isolated `UserDefaults` suite.
@Suite("PreferencesStore")
struct PreferencesStoreTests {
    /// A fresh, empty defaults domain, removed when the test ends.
    final class Suite {
        let name = "PetScapePlatformTests.\(UUID().uuidString)"
        let defaults: UserDefaults

        init() throws {
            defaults = try #require(UserDefaults(suiteName: name))
        }

        deinit {
            UserDefaults().removePersistentDomain(forName: name)
        }
    }

    @Test func defaultsAreRunningAndVisible() throws {
        let suite = try Suite()
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(!store.isPaused)
        #expect(!store.isHidden)
        #expect(!store.isWindowInteractionEnabled)
        #expect(store.userIntent == UserIntent())
    }

    @Test func windowInteractionOptInDefaultsOffAndPersists() throws {
        let suite = try Suite()
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(!store.isWindowInteractionEnabled)
        #expect(suite.defaults.object(forKey: "petscape.windowInteraction") == nil)
        store.isWindowInteractionEnabled = true
        #expect(UserDefaultsPreferencesStore(defaults: suite.defaults).isWindowInteractionEnabled)
        store.restoreDefaults()
        #expect(!store.isWindowInteractionEnabled)
    }

    @Test func musicOptInDefaultsOffPersistsAndRestoresWithoutChangingOtherKeys() throws {
        let suite = try Suite()
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(!store.isMusicDancingEnabled)
        #expect(suite.defaults.object(forKey: "petscape.musicDancing") == nil)
        store.isMusicDancingEnabled = true
        #expect(UserDefaultsPreferencesStore(defaults: suite.defaults).isMusicDancingEnabled)
        suite.defaults.set("retained", forKey: "unrelated.key")
        store.restoreDefaults()
        #expect(!store.isMusicDancingEnabled)
        #expect(suite.defaults.string(forKey: "unrelated.key") == "retained")
    }

    @Test func valuesSurviveANewStore() throws {
        let suite = try Suite()
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        store.isPaused = true
        store.isHidden = true
        let relaunched = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(relaunched.userIntent == UserIntent(isPaused: true, isHidden: true))
        relaunched.isHidden = false
        #expect(UserDefaultsPreferencesStore(defaults: suite.defaults).userIntent == UserIntent(isPaused: true))
    }

    @Test func keysAreNamespacedAndVersioned() throws {
        let suite = try Suite()
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        store.isPaused = true
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 3)
        #expect(suite.defaults.bool(forKey: "petscape.isPaused"))
        #expect(suite.defaults.object(forKey: "petscape.isHidden") == nil)
    }

    @Test func dockOffsetDefaultsToZeroPersistsAndStaysInRange() throws {
        let suite = try Suite()
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(store.dockOffsetAdjustment == 0)
        #expect(suite.defaults.object(forKey: "petscape.dockOffsetAdjustment") == nil)
        store.dockOffsetAdjustment = -3.5
        #expect(UserDefaultsPreferencesStore(defaults: suite.defaults).dockOffsetAdjustment == -3.5)
        store.dockOffsetAdjustment = 75
        #expect(suite.defaults.double(forKey: "petscape.dockOffsetAdjustment") == 40)
        suite.defaults.set(-500.0, forKey: "petscape.dockOffsetAdjustment")  // edited by hand
        #expect(store.dockOffsetAdjustment == -40)
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 3)
    }

    @Test func inMemoryStoreKeepsValues() {
        let store = InMemoryPreferencesStore(isPaused: true)
        #expect(store.userIntent == UserIntent(isPaused: true))
        store.isHidden = true
        #expect(store.isHidden)
        store.dockOffsetAdjustment = -41
        #expect(store.dockOffsetAdjustment == -40)
        #expect(InMemoryPreferencesStore(dockOffsetAdjustment: 2).dockOffsetAdjustment == 2)
    }
    @Test func versionOneMigrationPreservesIntentAndDockAndDefaultsToAutonomy() throws {
        let suite = try Suite()
        suite.defaults.set(1, forKey: "petscape.preferencesVersion")
        suite.defaults.set(true, forKey: "petscape.isPaused")
        suite.defaults.set(true, forKey: "petscape.isHidden")
        suite.defaults.set(-7.5, forKey: "petscape.dockOffsetAdjustment")
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(store.userIntent == UserIntent(isPaused: true, isHidden: true))
        #expect(store.dockOffsetAdjustment == -7.5)
        #expect(store.petSettings == PetSettings())
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 3)
    }

    @Test func interactionDefaultsAndVersionTwoMigrationPreserveOldValues() throws {
        let suite = try Suite()
        suite.defaults.set(2, forKey: "petscape.preferencesVersion")
        suite.defaults.set(false, forKey: "petscape.autonomy")
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(store.petSettings.interaction == InteractionSettings())
        #expect(!store.petSettings.behavior.isEnabled)
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 3)

        store.petSettings = PetSettings(
            interaction: InteractionSettings(
                cursorReactionsEnabled: false, directInteractionEnabled: false))
        #expect(
            UserDefaultsPreferencesStore(defaults: suite.defaults).petSettings.interaction
                == InteractionSettings(
                    cursorReactionsEnabled: false, directInteractionEnabled: false))
    }

    @Test func petSettingsPersistClampAndMatchMemoryStore() throws {
        let suite = try Suite()
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        let settings = PetSettings(
            scale: 1.4, speed: 1.8,
            behavior: AutonomySettings(
                isEnabled: false, jumpsEnabled: false, restEnabled: false, expressionsEnabled: false))
        store.petSettings = settings
        #expect(UserDefaultsPreferencesStore(defaults: suite.defaults).petSettings == settings)
        let memory = InMemoryPreferencesStore(petSettings: settings)
        #expect(memory.petSettings == settings)
        suite.defaults.set(9.0, forKey: "petscape.scale")
        suite.defaults.set(-9.0, forKey: "petscape.speed")
        #expect(store.petSettings.scale == 1.5)
        #expect(store.petSettings.speed == 0.5)
        suite.defaults.set(Double.nan, forKey: "petscape.scale")
        suite.defaults.set(Double.infinity, forKey: "petscape.speed")
        #expect(store.petSettings.scale == 1)
        #expect(store.petSettings.speed == PetSettings.defaultSpeed)
    }

    @Test func futureVersionAndUnrelatedKeysSurviveOpeningAndRestore() throws {
        let suite = try Suite()
        suite.defaults.set(99, forKey: "petscape.preferencesVersion")
        suite.defaults.set("future", forKey: "petscape.futureFeature")
        suite.defaults.set("other", forKey: "unrelated")
        let store = UserDefaultsPreferencesStore(defaults: suite.defaults)
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 99)
        store.isPaused = true
        store.isHidden = true
        store.dockOffsetAdjustment = 7
        store.petSettings = PetSettings(scale: 0.5, speed: 2, behavior: AutonomySettings(isEnabled: false))
        store.restoreDefaults()
        #expect(store.userIntent == UserIntent())
        #expect(store.dockOffsetAdjustment == 0)
        #expect(store.petSettings == PetSettings())
        #expect(suite.defaults.object(forKey: "petscape.cursorReactions") == nil)
        #expect(suite.defaults.object(forKey: "petscape.directInteraction") == nil)
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 99)
        #expect(suite.defaults.string(forKey: "petscape.futureFeature") == "future")
        #expect(suite.defaults.string(forKey: "unrelated") == "other")
        let memory = InMemoryPreferencesStore(
            isPaused: true, isHidden: true, dockOffsetAdjustment: -8,
            petSettings: PetSettings(scale: 1.5, speed: 0.5))
        memory.restoreDefaults()
        #expect(memory.userIntent == UserIntent())
        #expect(memory.dockOffsetAdjustment == 0)
        #expect(memory.petSettings == PetSettings())
    }

}
