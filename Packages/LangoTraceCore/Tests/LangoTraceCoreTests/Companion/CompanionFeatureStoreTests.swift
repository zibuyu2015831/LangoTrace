import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Companion feature store")
struct CompanionFeatureStoreTests {
    @Test("companionFeatureDefaultsToDisabled — no stored value reads as off")
    func companionFeatureDefaultsToDisabled() throws {
        let suiteName = "CompanionFeatureStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCompanionFeatureStore(defaults: defaults)
        #expect(store.isEnabled == false)
    }

    @Test("companionFeatureTogglePersists — enabling persists and reset returns to off")
    func companionFeatureTogglePersists() throws {
        let suiteName = "CompanionFeatureStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCompanionFeatureStore(defaults: defaults)
        store.isEnabled = true
        #expect(store.isEnabled == true)
        #expect(defaults.object(forKey: UserDefaultsCompanionFeatureStore.storageKey) as? Bool == true)

        let reread = UserDefaultsCompanionFeatureStore(defaults: defaults)
        #expect(reread.isEnabled == true)

        store.reset()
        #expect(store.isEnabled == false)
        #expect(defaults.object(forKey: UserDefaultsCompanionFeatureStore.storageKey) == nil)
    }
}
