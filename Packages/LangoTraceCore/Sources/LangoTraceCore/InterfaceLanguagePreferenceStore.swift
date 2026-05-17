import Foundation

public protocol InterfaceLanguagePreferenceStore: AnyObject, Sendable {
    var preference: InterfaceLanguagePreference { get set }
    func reset()
}

public final class UserDefaultsInterfaceLanguageStore: InterfaceLanguagePreferenceStore, @unchecked Sendable {
    public static let storageKey = "interfaceLanguagePreference"

    private let defaults: UserDefaults

    public var preference: InterfaceLanguagePreference {
        get {
            InterfaceLanguagePreference(
                storageValue: defaults.string(forKey: Self.storageKey)
                    ?? InterfaceLanguagePreference.system.storageValue
            )
        }
        set {
            defaults.set(newValue.storageValue, forKey: Self.storageKey)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
