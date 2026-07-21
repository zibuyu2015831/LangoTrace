import Foundation

/// Confidence in a band estimate. v1 signals (comprehension + coverage) are
/// sparse, so estimates are conservative and mostly `.low`.
public enum BandConfidence: String, Codable, CaseIterable, Equatable, Sendable {
    case low
    case medium
    case high
}

/// Direction of change in a band estimate, for the gentle overview presentation
/// (ADR-006 §10: only growth / steadiness is shown — never a "downgrade" verdict).
public enum BandTrend: String, Codable, CaseIterable, Equatable, Sendable {
    case steady
    case growing
}

/// An internal, re-estimated proficiency band (LM02-S4b). The **evaluated value**
/// behind core decision #6 (ADR-006 §10): it evolves from independent behaviour
/// signals (lookups + recurring errors + practice) and feeds `derive()` via
/// hysteresis — but **never overwrites the user-visible `LanguageLevel` label and
/// never shows a downgrade**.
public struct LearnerBand: Sendable, Equatable {
    public let languageCode: String
    /// The internal estimated level. May differ from the seed onboarding level;
    /// a lower estimate means more support (easier explanation tier), not a
    /// user-facing downgrade.
    public let estimatedLevel: LanguageLevel
    public let confidence: BandConfidence
    public let trend: BandTrend

    public init(
        languageCode: String,
        estimatedLevel: LanguageLevel,
        confidence: BandConfidence,
        trend: BandTrend
    ) {
        self.languageCode = languageCode
        self.estimatedLevel = estimatedLevel
        self.confidence = confidence
        self.trend = trend
    }
}

/// Hysteresis state machine guarding `ExplanationLanguageMode.derive()` against
/// drift (ADR-006 §10.1). One evaluation per **document-open**; the effective
/// level only changes when the band crosses to a new level for a sustained run
/// (`stableThreshold` consecutive evaluations) **and** the post-switch dwell
/// window has elapsed. The counter is in-memory, per-language; restart clearing
/// is an acceptable degradation (it just re-stabilises).
public struct BandHysteresis: Sendable, Equatable {
    public private(set) var effectiveLevel: LanguageLevel
    private var pendingTarget: LanguageLevel?
    private var consecutiveCount: Int
    private var opensSinceSwitch: Int
    private let stableThreshold: Int
    private let dwellWindow: Int

    public init(seed: LanguageLevel, stableThreshold: Int = 3, dwellWindow: Int = 5) {
        effectiveLevel = seed
        pendingTarget = nil
        consecutiveCount = 0
        // Seed so the first switch is gated only by the stable threshold, not by
        // the dwell window (there has been no prior switch to dwell after).
        opensSinceSwitch = dwellWindow
        self.stableThreshold = stableThreshold
        self.dwellWindow = dwellWindow
    }

    /// Feeds one document-open band evaluation; returns the (possibly unchanged)
    /// effective level to pass to `derive()`.
    @discardableResult
    public mutating func evaluate(bandLevel: LanguageLevel) -> LanguageLevel {
        opensSinceSwitch += 1
        guard bandLevel != effectiveLevel else {
            pendingTarget = nil
            consecutiveCount = 0
            return effectiveLevel
        }
        if bandLevel == pendingTarget {
            consecutiveCount += 1
        } else {
            pendingTarget = bandLevel
            consecutiveCount = 1
        }
        if consecutiveCount >= stableThreshold, opensSinceSwitch >= dwellWindow {
            effectiveLevel = bandLevel
            pendingTarget = nil
            consecutiveCount = 0
            opensSinceSwitch = 0
        }
        return effectiveLevel
    }
}
