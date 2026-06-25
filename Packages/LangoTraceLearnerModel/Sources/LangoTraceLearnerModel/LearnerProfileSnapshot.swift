import Foundation
import LangoTraceCore

/// Simple v1 growth trend for the learner profile overview (idea-02 §14.2 keeps
/// v1 to gentle counts, never a downgrade verdict).
public struct LearnerProfileTrend: Sendable, Equatable {
    /// Memory items deposited this week (borrowed from the review statistics).
    public let depositedThisWeek: Int
    /// Distinct knowledge-coverage entries for the current language.
    public let coverageEntryCount: Int

    public init(depositedThisWeek: Int, coverageEntryCount: Int) {
        self.depositedThisWeek = depositedThisWeek
        self.coverageEntryCount = coverageEntryCount
    }
}

/// Compute-on-read aggregate for the three-platform 学习画像 overview page (§12.4).
///
/// Field provenance is deliberately explicit:
/// - **Learner-owned**: `abilityCoverage` (compute-on-read from deposits) and
///   `memoryFacts` (the system-level Memory layer).
/// - **Borrowed for display**: `reviewStatistics` comes from the per-space
///   `memory_items` review queue (owned by the memory feature, NOT the Learner
///   Model). A system-level Memory reset must never alter it.
public struct LearnerProfileSnapshot: Sendable, Equatable {
    // Learner-owned.
    public let abilityCoverage: AbilityCoverage
    public let memoryFacts: [MemoryFact]
    /// Recurring practice error patterns (LM02-S3), compute-on-read from dictation
    /// attempts. Empty until the learner has done dictation practice.
    public let blindSpots: [BlindSpot]
    /// Internal re-estimated band (LM02-S4b); `nil` when no band provider is wired.
    /// Presented only as gentle trend / confidence — never as a downgrade verdict
    /// and never overwriting the user-visible level (ADR-006 §10).
    public let band: LearnerBand?
    /// Borrowed for display (per-space memory_items review queue).
    public let reviewStatistics: MemoryStatistics
    /// Derived.
    public let trend: LearnerProfileTrend

    public init(
        abilityCoverage: AbilityCoverage,
        memoryFacts: [MemoryFact],
        blindSpots: [BlindSpot] = [],
        band: LearnerBand? = nil,
        reviewStatistics: MemoryStatistics,
        trend: LearnerProfileTrend
    ) {
        self.abilityCoverage = abilityCoverage
        self.memoryFacts = memoryFacts
        self.blindSpots = blindSpots
        self.band = band
        self.reviewStatistics = reviewStatistics
        self.trend = trend
    }
}

/// Builds a `LearnerProfileSnapshot` for the current space + language. Lives in
/// `LangoTraceLearnerModel` and **borrows** the `MemoryItemRepository` (Data-owned)
/// purely to read review statistics — it does not own that data.
///
/// `async` because the review statistics read is async; the synchronous Ability /
/// Memory reads run inside the async context. Pure read, no side effects.
public struct LearnerProfileSnapshotBuilder: Sendable {
    private let provider: any LearnerContextProvider
    private let memoryItemRepository: any MemoryItemRepository
    /// Optional blind-spot read (LM02-S3); `nil` leaves blind spots empty.
    private let blindSpotProvider: (any LearnerBlindSpotProvider)?
    /// Optional band read (LM02-S4b); `nil` leaves the band absent.
    private let bandProvider: (any LearnerBandProvider)?

    public init(
        provider: any LearnerContextProvider,
        memoryItemRepository: any MemoryItemRepository,
        blindSpotProvider: (any LearnerBlindSpotProvider)? = nil,
        bandProvider: (any LearnerBandProvider)? = nil
    ) {
        self.provider = provider
        self.memoryItemRepository = memoryItemRepository
        self.blindSpotProvider = blindSpotProvider
        self.bandProvider = bandProvider
    }

    /// Snapshot for the given space + language. The caller (UI store) supplies the
    /// partition keys + the seed (onboarding) level from the active space; the
    /// snapshot does not guess them.
    public func snapshot(
        spaceID: String,
        languageCode: String,
        seedLevel: LanguageLevel,
        now: Date
    ) async throws -> LearnerProfileSnapshot {
        let abilityCoverage = try provider.abilityCoverage(languageCode: languageCode)
        let memoryFacts = try provider.memoryFacts(visibility: nil)
        var blindSpots: [BlindSpot] = []
        if let blindSpotProvider {
            blindSpots = (try? blindSpotProvider.blindSpots(languageCode: languageCode)) ?? []
        }
        var band: LearnerBand?
        if let bandProvider {
            band = try? bandProvider.band(languageCode: languageCode, seedLevel: seedLevel)
        }
        let reviewStatistics = try await memoryItemRepository.memoryStatistics(spaceID: spaceID, now: now)
        let trend = LearnerProfileTrend(
            depositedThisWeek: reviewStatistics.depositedThisWeek,
            coverageEntryCount: abilityCoverage.entries.count
        )
        return LearnerProfileSnapshot(
            abilityCoverage: abilityCoverage,
            memoryFacts: memoryFacts,
            blindSpots: blindSpots,
            band: band,
            reviewStatistics: reviewStatistics,
            trend: trend
        )
    }
}
