import Foundation
import GRDB

/// Identifies one analysis-ledger entry (ADR-006 §9): the source stream, its id,
/// the analyzer, and its version. A version bump is a different key → a fresh
/// cursor → a full re-run.
public struct AnalysisLedgerKey: Sendable, Equatable {
    public let sourceType: String
    public let sourceID: String
    public let analyzer: String
    public let analyzerVersion: Int

    public init(sourceType: String, sourceID: String, analyzer: String, analyzerVersion: Int) {
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.analyzer = analyzer
        self.analyzerVersion = analyzerVersion
    }
}

/// ADR-006 §9 analysis ledger: a high-water cursor per `(source_type, source_id,
/// analyzer, analyzer_version)` for **incremental window aggregation** — never a
/// per-item flag. The cursor only ever moves forward (monotonic); a stale advance
/// is ignored, so re-entry / concurrency cannot double-advance or regress it.
public struct GRDBAnalysisLedgerRepository: Sendable {
    private let writer: DatabaseWriter

    public init(writer: DatabaseWriter) {
        self.writer = writer
    }

    /// The current high-water cursor for a key, or 0 when no entry exists (a fresh
    /// analyzer / version starts from the beginning).
    public func cursorPosition(_ key: AnalysisLedgerKey) throws -> Double {
        try writer.read { db in
            try Double.fetchOne(
                db,
                sql: """
                SELECT cursor_position FROM analysis_ledger
                WHERE source_type = ? AND source_id = ? AND analyzer = ? AND analyzer_version = ?
                """,
                arguments: [key.sourceType, key.sourceID, key.analyzer, key.analyzerVersion]
            ) ?? 0
        }
    }

    /// Advances the cursor to `position` if it is past the current high-water mark,
    /// upserting the ledger row. A lower `position` is a no-op (monotonic).
    public func advanceCursor(_ key: AnalysisLedgerKey, to position: Double, now: Date = Date()) throws {
        try writer.write { db in
            let existing = try Double.fetchOne(
                db,
                sql: """
                SELECT cursor_position FROM analysis_ledger
                WHERE source_type = ? AND source_id = ? AND analyzer = ? AND analyzer_version = ?
                """,
                arguments: [key.sourceType, key.sourceID, key.analyzer, key.analyzerVersion]
            )
            if let existing {
                guard position > existing else { return }
                try db.execute(
                    sql: """
                    UPDATE analysis_ledger SET cursor_position = ?, updated_at = ?
                    WHERE source_type = ? AND source_id = ? AND analyzer = ? AND analyzer_version = ?
                    """,
                    arguments: [
                        position, now.timeIntervalSince1970,
                        key.sourceType, key.sourceID, key.analyzer, key.analyzerVersion,
                    ]
                )
            } else {
                try db.execute(
                    sql: """
                    INSERT INTO analysis_ledger
                    (id, source_type, source_id, analyzer, analyzer_version, cursor_position, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        "\(key.sourceType)|\(key.sourceID)|\(key.analyzer)|\(key.analyzerVersion)",
                        key.sourceType, key.sourceID, key.analyzer, key.analyzerVersion,
                        position, now.timeIntervalSince1970,
                    ]
                )
            }
        }
    }
}
