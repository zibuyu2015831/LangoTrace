import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Interface language preference store")
struct InterfaceLanguagePreferenceStoreTests {
    @Test("Store reads system by default")
    func readsSystemByDefault() {
        let defaults = Self.makeDefaults(named: "default")
        let store = UserDefaultsInterfaceLanguageStore(defaults: defaults)

        #expect(store.preference == .system)
    }

    @Test("Store persists explicit preference")
    func persistsExplicitPreference() {
        let defaults = Self.makeDefaults(named: "persist")
        let store = UserDefaultsInterfaceLanguageStore(defaults: defaults)

        store.preference = .simplifiedChinese

        #expect(UserDefaultsInterfaceLanguageStore(defaults: defaults).preference == .simplifiedChinese)
    }

    @Test("Store recovers invalid values as system")
    func recoversInvalidValues() {
        let defaults = Self.makeDefaults(named: "invalid")
        defaults.set("fr", forKey: UserDefaultsInterfaceLanguageStore.storageKey)

        let store = UserDefaultsInterfaceLanguageStore(defaults: defaults)

        #expect(store.preference == .system)
    }

    @Test("Store resets preference")
    func resetsPreference() {
        let defaults = Self.makeDefaults(named: "reset")
        let store = UserDefaultsInterfaceLanguageStore(defaults: defaults)
        store.preference = .english

        store.reset()

        #expect(store.preference == .system)
        #expect(defaults.string(forKey: UserDefaultsInterfaceLanguageStore.storageKey) == nil)
    }

    private static func makeDefaults(named name: String) -> UserDefaults {
        let suiteName = "InterfaceLanguagePreferenceStoreTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
