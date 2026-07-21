import Foundation
import GRDB
import LangoTraceCore

/// Re-estimates the internal proficiency band on read from **independent
/// behaviour signals** (LM02-S4b): userAuthored dictionary lookups (S4a) + recurring
/// errors (S3 blind spots). Compute-on-read, no new table — the band can always be
/// recomputed from the signals.
///
/// **Closed-loop red line (ADR-006 §4 / idea-02 §13.1)**: the band is built only on
/// user behaviour / production. It never reads `memory_candidates.difficulty` /
/// `learning_materials.learning_text` / AI judgement — the SQL touches only
/// `dictionary_lookup_events` + `language_spaces`, and recurring errors come from the
/// red-line-clean `LearnerBlindSpotProvider`. A source-level grep + behaviour
/// assertion guard this.
///
/// **No downgrade verdict / no label overwrite (ADR-006 §10)**: the band is an
/// internal value only; it never writes `language_spaces.level`. v1 is conservative
/// — a strong struggling signal nudges the estimate **down one level** (more support
/// in `derive()`), and confidence stays `.low` (sparse v1 signals).
public struct GRDBLearnerBandProvider: LearnerBandProvider {
    private let reader: DatabaseReader
    private let blindSpotProvider: any LearnerBlindSpotProvider
    private let strugglingThreshold: Int

    public init(
        reader: DatabaseReader,
        blindSpotProvider: any LearnerBlindSpotProvider,
        strugglingThreshold: Int = 12
    ) {
        self.reader = reader
        self.blindSpotProvider = blindSpotProvider
        self.strugglingThreshold = strugglingThreshold
    }

    public func band(languageCode: String, seedLevel: LanguageLevel) throws -> LearnerBand {
        // userAuthored lookups across all spaces of this target language. The
        // `aiGenerated` filter breaks the second-order closure (S4a forward seam).
        let lookupCount = try reader.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM dictionary_lookup_events dle
                JOIN language_spaces ls ON dle.language_space_id = ls.id
                WHERE ls.target_language_code = ?
                  AND dle.source_content_origin = 'userAuthored'
                  AND dle.soft_deleted_at IS NULL
                  AND ls.deleted_at IS NULL
                """,
                arguments: [languageCode]
            ) ?? 0
        }
        let errorCount = try blindSpotProvider.blindSpots(languageCode: languageCode)
            .reduce(0) { $0 + $1.occurrenceCount }
        let strugglingScore = lookupCount + errorCount

        let estimatedLevel = strugglingScore >= strugglingThreshold
            ? Self.oneLevelDown(seedLevel)
            : seedLevel
        return LearnerBand(
            languageCode: languageCode,
            estimatedLevel: estimatedLevel,
            confidence: .low,
            trend: .steady
        )
    }

    private static func oneLevelDown(_ level: LanguageLevel) -> LanguageLevel {
        let ordered = LanguageLevel.allCases
        guard let index = ordered.firstIndex(of: level), index > 0 else { return level }
        return ordered[index - 1]
    }
}
