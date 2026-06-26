import Foundation

/// Pure decision seam for the companion Memory-injection gate (LM03-S2b-1).
///
/// Lifting "should we inject, and with what context" out of the App-Shell async
/// send path makes the highest privacy gate **structurally testable**: the four
/// states (`notDecided` / `disabled` / `enabled`+toggle-off / `enabled`+toggle-on)
/// can each be asserted as a fail-first unit test, instead of trusting an opaque
/// code path inside `AppEnvironment+Companion`.
///
/// The App still owns reading the authoritative inputs at the last moment
/// (consent from `UserDefaults`, `threadUsesProfile` from the same `thread` row
/// it sends with), then calls these pure functions. The store-side
/// `canInjectMemory` is for UI presentation only and is *not* the egress
/// authority.
public enum CompanionInjectionGate {
    /// Inject only when the user has globally consented AND the per-conversation
    /// toggle is on. `notDecided` and `disabled` both block injection.
    public static func shouldInject(
        consent: CompanionMemoryConsent,
        threadUsesProfile: Bool
    ) -> Bool {
        consent == .enabled && threadUsesProfile
    }

    /// The rendered memory fragments to inject — the already-selected,
    /// already-scrubbed fact lines when the gate is open, otherwise empty.
    /// Operates on `[String]` so this seam stays in Core without depending on the
    /// LearnerModel fact types (selection + rendering happen upstream in App).
    public static func memoryContext(
        renderedFacts: [String],
        consent: CompanionMemoryConsent,
        threadUsesProfile: Bool
    ) -> [String] {
        shouldInject(consent: consent, threadUsesProfile: threadUsesProfile) ? renderedFacts : []
    }
}
