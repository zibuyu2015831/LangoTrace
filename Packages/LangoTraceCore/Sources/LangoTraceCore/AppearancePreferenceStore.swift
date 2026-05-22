import Foundation

public protocol AppearancePreferenceStore: AnyObject, Sendable {
    var preference: AppearancePreference { get set }
    func reset()
}

public final class UserDefaultsAppearancePreferenceStore: AppearancePreferenceStore, @unchecked Sendable {
    public static let storageKey = "appearancePreference"

    private let defaults: UserDefaults

    public var preference: AppearancePreference {
        get {
            AppearancePreference(
                storageValue: defaults.string(forKey: Self.storageKey)
                    ?? AppearancePreference.system.storageValue
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
