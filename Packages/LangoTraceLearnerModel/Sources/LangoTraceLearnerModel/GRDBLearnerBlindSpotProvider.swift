import Foundation
import GRDB
import LangoTraceCore

/// Computes blind spots on read from a learner's own dictation `practice_text_attempts`,
/// joined to `language_spaces` to resolve the target language (ADR-006 §3). Mirrors
/// the LM01 Ability provider: `reader.read{}`, no writer, no migration, source
/// deletion cascades for free via the active-only filters (ADR-006 §7/§8).
///
/// **Red line (ADR-006 §4)**: the SQL only FROM/JOINs `practice_text_attempts` +
/// `language_spaces` (the user's own production + mechanical diff). It never reads
/// `memory_candidates` / `learning_materials.learning_text` / AI judgement — a
/// behaviour the `GRDBLearnerBlindSpotProviderTests` red-line test and the
/// source-level grep guard both enforce.
///
/// The persisted `diff_summary_json` holds only kind + offsets (no word text), so
/// the provider re-runs `PracticeDictationDiff.compare()` on `attempt_text` +
/// `reference_text_snapshot` to recover the words for frequency aggregation. That
/// recompute is O(n²) LCS (capped at `maxInputLength`), so the read is bounded to
/// the most recent `recomputeLimit` attempts (default 200) — a stateless, no-cache,
/// no-migration size ceiling (约束 5).
public struct GRDBLearnerBlindSpotProvider: LearnerBlindSpotProvider {
    private let reader: DatabaseReader
    private let recomputeLimit: Int

    public init(reader: DatabaseReader, recomputeLimit: Int = 200) {
        self.reader = reader
        self.recomputeLimit = recomputeLimit
    }

    public func blindSpots(languageCode: String) throws -> [BlindSpot] {
        let rows = try reader.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT pta.id AS id,
                       pta.attempt_text AS attempt_text,
                       pta.reference_text_snapshot AS reference_text_snapshot
                FROM practice_text_attempts pta
                JOIN language_spaces ls ON pta.language_space_id = ls.id
                WHERE pta.exercise_type = 'dictation'
                  AND pta.diff_summary_json IS NOT NULL
                  AND pta.soft_deleted_at IS NULL
                  AND ls.deleted_at IS NULL
                  AND ls.target_language_code = ?
                ORDER BY pta.created_at DESC, pta.id ASC
                LIMIT ?
                """,
                arguments: [languageCode, recomputeLimit]
            )
        }
        return Self.aggregate(rows: rows, languageCode: languageCode)
    }

    /// Re-runs the mechanical diff per attempt and aggregates segments by
    /// (kind, representative word). Representative word = the reference word for
    /// missing/changed (the target the learner keeps getting wrong) and the
    /// attempt word for extra. Case-folded for grouping; display keeps the first
    /// seen surface form. Ordered by frequency desc, then text.
    private static func aggregate(rows: [Row], languageCode: String) -> [BlindSpot] {
        struct Bucket {
            var kind: BlindSpotKind
            var display: String
            var occurrenceCount: Int
            var attemptIDs: [String]
            var seenAttempts: Set<String>
        }
        var order: [String] = []
        var buckets: [String: Bucket] = [:]

        for row in rows {
            let id: String = row["id"]
            let attempt: String = row["attempt_text"]
            let reference: String = row["reference_text_snapshot"]
            guard let result = try? PracticeDictationDiff.compare(attempt: attempt, reference: reference) else {
                continue
            }
            for segment in result.segments {
                let kind = BlindSpotKind(segmentKind: segment.kind)
                guard let word = representativeWord(for: segment), !word.isEmpty else { continue }
                let key = "\(kind.rawValue)|\(word.lowercased())"
                if var bucket = buckets[key] {
                    bucket.occurrenceCount += 1
                    if bucket.seenAttempts.insert(id).inserted {
                        bucket.attemptIDs.append(id)
                    }
                    buckets[key] = bucket
                } else {
                    order.append(key)
                    buckets[key] = Bucket(
                        kind: kind,
                        display: word,
                        occurrenceCount: 1,
                        attemptIDs: [id],
                        seenAttempts: [id]
                    )
                }
            }
        }

        let spots = order.compactMap { key -> BlindSpot? in
            guard let bucket = buckets[key] else { return nil }
            return BlindSpot(
                languageCode: languageCode,
                kind: bucket.kind,
                representativeText: bucket.display,
                occurrenceCount: bucket.occurrenceCount,
                evidence: bucket.attemptIDs.map {
                    LearnerEvidenceRef(sourceType: .practiceTextAttempt, sourceID: $0)
                }
            )
        }
        return spots.sorted {
            if $0.occurrenceCount != $1.occurrenceCount {
                return $0.occurrenceCount > $1.occurrenceCount
            }
            return $0.representativeText < $1.representativeText
        }
    }

    private static func representativeWord(for segment: PracticeDictationDiff.Segment) -> String? {
        switch segment.kind {
        case .missing, .changed:
            segment.referenceText
        case .extra:
            segment.attemptText
        }
    }
}
