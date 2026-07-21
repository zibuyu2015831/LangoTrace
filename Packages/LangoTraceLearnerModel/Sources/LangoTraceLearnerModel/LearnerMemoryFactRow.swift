import Foundation
import GRDB

/// Shared `learner_memory_facts` row → `MemoryFact` decode, used by both the
/// write-owning `GRDBLearnerMemoryRepository` and the read-only
/// `GRDBLearnerContextProvider`, so the two stay in sync on column mapping.
enum LearnerMemoryFactRow {
    /// The non-policy columns both readers select, in a stable order.
    static let selectedColumns = """
    id, kind, text, salience, visibility, source, source_entry_id, created_at, soft_deleted_at
    """

    static func fact(from row: Row) -> MemoryFact? {
        guard let kind = MemoryFactKind(rawValue: row["kind"]),
              let visibility = MemoryFactVisibility(rawValue: row["visibility"]),
              let source = LearnerSourceType(rawValue: row["source"])
        else {
            return nil
        }
        let softDeletedAt: Date? = (row["soft_deleted_at"] as Double?).map { Date(timeIntervalSince1970: $0) }
        return MemoryFact(
            id: row["id"],
            kind: kind,
            text: row["text"],
            salience: row["salience"],
            visibility: visibility,
            source: source,
            sourceEntryID: row["source_entry_id"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            softDeletedAt: softDeletedAt
        )
    }
}
