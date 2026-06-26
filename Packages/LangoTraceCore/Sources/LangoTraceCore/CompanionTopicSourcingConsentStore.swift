import Foundation

/// Global, three-state consent for the companion to draw a conversation topic
/// from the user's own saved records (LM03-S2b-2 方案B). Like Memory injection
/// (S2b-1), this is a **system auto-injection** of user content into an outbound
/// request, so it is gated by a one-time first-enable preview (spec/008 §2 /
/// ADR-008 §6), never a per-send prompt:
/// - `notDecided`: not yet shown the one-time preview. The companion does **not**
///   source a topic from records (decision #10: no egress without consent), and
///   the first topic-capable send surfaces the one-time preview.
/// - `enabled`: the user accepted; the companion may bring in a record on a send
///   turn (subject to the per-conversation toggle).
/// - `disabled`: the user declined; never source a topic from records.
///
/// Separate from `CompanionMemoryConsent`: drawing a single full record is a
/// different privacy category from injecting distilled life facts, so the global
/// consents are physically isolated (only the per-conversation toggle is shared).
public enum CompanionTopicSourcingConsent: String, Codable, Sendable, Equatable, CaseIterable {
    case notDecided
    case enabled
    case disabled
}

public protocol CompanionTopicSourcingConsentStore: AnyObject, Sendable {
    var consent: CompanionTopicSourcingConsent { get set }
    func reset()
}

public final class UserDefaultsCompanionTopicSourcingConsentStore: CompanionTopicSourcingConsentStore, @unchecked Sendable {
    public static let storageKey = "LanguageCompanionTopicSourcing"

    private let defaults: UserDefaults

    /// Defaults to `.notDecided` until the user passes the one-time preview.
    public var consent: CompanionTopicSourcingConsent {
        get {
            guard let raw = defaults.string(forKey: Self.storageKey),
                  let value = CompanionTopicSourcingConsent(rawValue: raw)
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
