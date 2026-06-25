import Foundation
import LangoTraceCore
import LangoTraceLearnerModel

/// Gentle proficiency display for the learner profile overview (constraint 5 /
/// idea-02 §14.2). v1 shows only the static onboarding level, always marked as
/// still-calibrating — there is **deliberately no representation of a downgrade**,
/// so the page can never tell the user "you dropped from B1 to A2". Band
/// re-estimation is a later slice (ADR-006 §10).
public struct LearnerProfileLevelDisplay: Equatable, Sendable {
    public let level: LanguageLevel
    public let isCalibrating: Bool

    public init(level: LanguageLevel, isCalibrating: Bool) {
        self.level = level
        self.isCalibrating = isCalibrating
    }
}

/// One Memory fact rendered for the overview list.
public struct MemoryFactPresentation: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: MemoryFactKind
    public let text: String

    public init(id: String, kind: MemoryFactKind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

/// One recurring practice error pattern rendered for the blind-spot section
/// (LM02-S3). Honestly framed as a repeated practice error from dictation — never
/// a grammar verdict or a level judgement (constraint 4).
public struct BlindSpotPresentation: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: BlindSpotKind
    public let text: String
    public let occurrenceCount: Int

    public init(id: String, kind: BlindSpotKind, text: String, occurrenceCount: Int) {
        self.id = id
        self.kind = kind
        self.text = text
        self.occurrenceCount = occurrenceCount
    }
}

/// View state for the three-platform learner-profile overview page, mapped purely
/// from a `LearnerProfileSnapshot` plus the current space's onboarding level. No
/// SwiftUI, no IO — fully testable.
public struct LearnerProfilePresentation: Equatable, Sendable {
    public let levelDisplay: LearnerProfileLevelDisplay
    public let coverageEntryCount: Int
    public let dueCount: Int
    public let masteredCount: Int
    public let depositedThisWeek: Int
    public let memoryFacts: [MemoryFactPresentation]
    /// Recurring practice error patterns (LM02-S3), from the learner's own
    /// dictation attempts. Aggregated compute-on-read — never fabricated.
    public let blindSpots: [BlindSpotPresentation]
    /// `true` when there are no blind spots yet — the section shows guidance to do
    /// dictation practice (the signal source), not a "coming soon" feature stub.
    public let blindSpotsPlaceholder: Bool
    /// Drives the "keep recording to unlock your profile" empty state: no coverage,
    /// no facts, no review activity at all.
    public let isEmpty: Bool

    public init(snapshot: LearnerProfileSnapshot, level: LanguageLevel) {
        levelDisplay = LearnerProfileLevelDisplay(level: level, isCalibrating: true)
        coverageEntryCount = snapshot.abilityCoverage.entries.count
        dueCount = snapshot.reviewStatistics.dueCount
        masteredCount = snapshot.reviewStatistics.masteredCount
        depositedThisWeek = snapshot.trend.depositedThisWeek
        memoryFacts = snapshot.memoryFacts.map {
            MemoryFactPresentation(id: $0.id, kind: $0.kind, text: $0.text)
        }
        blindSpots = snapshot.blindSpots.map {
            BlindSpotPresentation(
                id: $0.id,
                kind: $0.kind,
                text: $0.representativeText,
                occurrenceCount: $0.occurrenceCount
            )
        }
        blindSpotsPlaceholder = snapshot.blindSpots.isEmpty
        isEmpty = snapshot.abilityCoverage.entries.isEmpty
            && snapshot.memoryFacts.isEmpty
            && snapshot.reviewStatistics == .zero
    }
}
