import Foundation
import GRDB

/// Computes Ability knowledge coverage on read from active deposited `memory_items`,
/// joined to `language_spaces` to resolve the target language code (ADR-006 §3).
///
/// Compute-on-read, no persistence (ADR-006 §8): the read path writes nothing, results
/// are discardable and recomputed each call, and source deletion cascades for free via
/// the `soft_deleted_at IS NULL` filter (ADR-006 §7). It reads ONLY user-deposited rows
/// and the language space — never `memory_candidates` or any AI difficulty signal
/// (ADR-006 §4 red line).
public struct GRDBLearnerContextProvider: LearnerContextProvider {
    private let reader: DatabaseReader
    private let clock: @Sendable () -> Date

    public init(reader: DatabaseReader, clock: @escaping @Sendable () -> Date = Date.init) {
        self.reader = reader
        self.clock = clock
    }

    public func abilityCoverage(languageCode: String) throws -> AbilityCoverage {
        let rows = try reader.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT mi.id AS id, mi.text AS text, mi.kind AS kind
                FROM memory_items mi
                JOIN language_spaces ls ON mi.space_id = ls.id
                WHERE ls.target_language_code = ?
                  AND mi.soft_deleted_at IS NULL
                  AND ls.deleted_at IS NULL
                ORDER BY mi.created_at ASC, mi.id ASC
                """,
                arguments: [languageCode]
            )
        }

        let entries = Self.aggregate(rows: rows)
        return AbilityCoverage(languageCode: languageCode, entries: entries, generatedAt: clock())
    }

    /// Merges raw rows into coverage entries by target text, preserving first-seen order,
    /// counting occurrences, and collecting one evidence ref per source row. A row whose
    /// `kind` is not a known structural kind is skipped (defensive; the CHECK constraint
    /// already restricts it to the two v1 values).
    private static func aggregate(rows: [Row]) -> [AbilityCoverageEntry] {
        var order: [String] = []
        var byText: [String: (kind: AbilityCoverageKind, count: Int, evidence: [LearnerEvidenceRef])] = [:]

        for row in rows {
            let text: String = row["text"]
            let rawKind: String = row["kind"]
            let id: String = row["id"]
            guard let kind = AbilityCoverageKind(rawValue: rawKind) else { continue }

            let ref = LearnerEvidenceRef(sourceType: .memoryItem, sourceID: id)
            if var existing = byText[text] {
                existing.count += 1
                existing.evidence.append(ref)
                byText[text] = existing
            } else {
                order.append(text)
                byText[text] = (kind: kind, count: 1, evidence: [ref])
            }
        }

        return order.compactMap { text in
            guard let bucket = byText[text] else { return nil }
            return AbilityCoverageEntry(
                text: text,
                kind: bucket.kind,
                occurrenceCount: bucket.count,
                evidence: bucket.evidence
            )
        }
    }
}
