import Foundation

/// App-level (per-device) on/off switch for the Language Companion feature.
/// Default OFF (ADR-008 §2.6): when disabled the three-platform entries do not
/// appear and the data / AI paths are not activated. Mirrors the existing
/// `AppearancePreferenceStore` / `InterfaceLanguagePreferenceStore` pattern.
public protocol CompanionFeaturePreferenceStore: AnyObject, Sendable {
    var isEnabled: Bool { get set }
    func reset()
}

public final class UserDefaultsCompanionFeatureStore: CompanionFeaturePreferenceStore, @unchecked Sendable {
    public static let storageKey = "LanguageCompanionEnabled"

    private let defaults: UserDefaults

    /// Defaults to `false` when no value has been stored (feature off until the
    /// user explicitly opts in).
    public var isEnabled: Bool {
        get { defaults.object(forKey: Self.storageKey) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Self.storageKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
