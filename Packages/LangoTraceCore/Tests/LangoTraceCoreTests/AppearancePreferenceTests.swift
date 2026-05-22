import Foundation
@testable import LangoTraceCore
import Testing

@Test("Appearance preference uses stable storage values")
func appearancePreferenceUsesStableStorageValues() {
    #expect(AppearancePreference.system.storageValue == "system")
    #expect(AppearancePreference.light.storageValue == "light")
    #expect(AppearancePreference.dark.storageValue == "dark")
    #expect(AppearancePreference(storageValue: "system") == .system)
    #expect(AppearancePreference(storageValue: "light") == .light)
    #expect(AppearancePreference(storageValue: "dark") == .dark)
    #expect(AppearancePreference(storageValue: "missing") == .system)
}

@Test("UserDefaults appearance store persists and resets device preference")
func userDefaultsAppearanceStorePersistsAndResetsDevicePreference() throws {
    let suiteName = "AppearancePreferenceTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }
    let store = UserDefaultsAppearancePreferenceStore(defaults: defaults)

    #expect(store.preference == .system)

    store.preference = .dark
    #expect(store.preference == .dark)
    #expect(defaults.string(forKey: UserDefaultsAppearancePreferenceStore.storageKey) == "dark")

    store.preference = .light
    #expect(store.preference == .light)

    store.reset()
    #expect(store.preference == .system)
    #expect(defaults.string(forKey: UserDefaultsAppearancePreferenceStore.storageKey) == nil)
}
