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
        #expect(store.userIntent == UserIntent())
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
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 1)
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
        #expect(suite.defaults.integer(forKey: "petscape.preferencesVersion") == 1)
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
}
