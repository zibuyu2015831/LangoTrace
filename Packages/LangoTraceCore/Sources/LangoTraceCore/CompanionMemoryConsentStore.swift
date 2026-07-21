import Foundation

/// Global, three-state consent for injecting the learner's long-term memory
/// (life facts) into companion requests (LM03-S2b-1, the highest privacy gate).
///
/// The authorization UX is fixed by spec/008 §2 / ADR-008 §6 / product-main-ref
/// §27.3 as a **one-time first-enable preview**, not a per-send prompt:
/// - `notDecided`: the user has not yet seen the one-time preview. Memory is
///   **not** injected (decision #10: no egress of the profile without consent),
///   and the first injection-capable entry surfaces the one-time preview.
/// - `enabled`: the user accepted the preview; injection proceeds (subject to the
///   per-conversation `uses_learner_profile` toggle).
/// - `disabled`: the user chose "don't use my learner profile"; never inject.
public enum CompanionMemoryConsent: String, Codable, Sendable, Equatable, CaseIterable {
    case notDecided
    case enabled
    case disabled
}

/// Persists the global memory-injection consent. Non-sensitive — lives in
/// `UserDefaults` alongside `CompanionFeaturePreferenceStore`.
public protocol CompanionMemoryConsentStore: AnyObject, Sendable {
    var consent: CompanionMemoryConsent { get set }
    func reset()
}

public final class UserDefaultsCompanionMemoryConsentStore: CompanionMemoryConsentStore, @unchecked Sendable {
    public static let storageKey = "LanguageCompanionMemoryConsent"

    private let defaults: UserDefaults

    /// Defaults to `.notDecided` until the user passes the one-time preview.
    public var consent: CompanionMemoryConsent {
        get {
            guard let raw = defaults.string(forKey: Self.storageKey),
                  let value = CompanionMemoryConsent(rawValue: raw)
            else { return .notDecided }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Self.storageKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
