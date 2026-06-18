import Foundation
import GRDB
import LangoTraceCore

/// GRDB-backed deposited memory store (E7). Deposits are idempotent per source
/// candidate (the partial unique index plus an existence check), so a double-tap
/// "加入记忆" returns the existing item rather than duplicating.
public struct GRDBMemoryItemRepository: MemoryItemRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let makeID: @Sendable () -> String

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        makeID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.makeID = makeID
    }

    public func deposit(_ input: MemoryDepositInput) async throws -> DepositedMemoryItem {
        let id = makeID()
        let now = clock()
        return try await databaseQueue.write { db in
            if let existing = try Self.fetchByCandidate(db, spaceID: input.spaceID, candidateID: input.sourceCandidateID) {
                return existing
            }
            let item = DepositedMemoryItem(
                id: id,
                spaceID: input.spaceID,
                entryID: input.entryID,
                sourceKind: .candidate,
                sourceCandidateID: input.sourceCandidateID,
                kind: input.kind,
                text: input.text,
                note: input.note,
                exampleTarget: input.exampleTarget,
                exampleNative: input.exampleNative,
                difficulty: input.difficulty,
                createdAt: now
            )
            try db.execute(
                sql: """
                INSERT INTO memory_items (
                    id, space_id, entry_id, source_kind, source_candidate_id, kind, text, note,
                    example_target, example_native, difficulty, review_state, review_rung,
                    review_due_at, last_reviewed_at, review_count, mastered_at, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'new', 0, NULL, NULL, 0, NULL, ?)
                """,
                arguments: [
                    item.id, item.spaceID, item.entryID, item.sourceKind.rawValue, item.sourceCandidateID,
                    item.kind.rawValue, item.text, item.note, item.exampleTarget, item.exampleNative,
                    item.difficulty.rawValue, item.createdAt.timeIntervalSince1970,
                ]
            )
            return item
        }
    }

    public func listMemoryItems(spaceID: String) async throws -> [DepositedMemoryItem] {
        try await databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM memory_items
                WHERE space_id = ? AND soft_deleted_at IS NULL
                ORDER BY created_at DESC, id DESC
                """,
                arguments: [spaceID]
            ).compactMap(Self.item(from:))
        }
    }

    public func depositedCandidateIDs(spaceID: String) async throws -> Set<String> {
        try await databaseQueue.read { db in
            let ids = try String.fetchAll(
                db,
                sql: """
                SELECT source_candidate_id FROM memory_items
                WHERE space_id = ? AND soft_deleted_at IS NULL AND source_candidate_id IS NOT NULL
                """,
                arguments: [spaceID]
            )
            return Set(ids)
        }
    }

    public func depositedEntryIDs(spaceID: String) async throws -> Set<String> {
        try await databaseQueue.read { db in
            let ids = try String.fetchAll(
                db,
                sql: """
                SELECT DISTINCT entry_id FROM memory_items
                WHERE space_id = ? AND soft_deleted_at IS NULL AND entry_id IS NOT NULL
                """,
                arguments: [spaceID]
            )
            return Set(ids)
        }
    }

    public func softDelete(id: String) async throws {
        let now = clock().timeIntervalSince1970
        try await databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE memory_items SET soft_deleted_at = ? WHERE id = ? AND soft_deleted_at IS NULL",
                arguments: [now, id]
            )
        }
    }
}

private extension GRDBMemoryItemRepository {
    static func fetchByCandidate(_ db: Database, spaceID: String, candidateID: String) throws -> DepositedMemoryItem? {
        try Row.fetchOne(
            db,
            sql: """
            SELECT * FROM memory_items
            WHERE space_id = ? AND source_candidate_id = ? AND soft_deleted_at IS NULL
            """,
            arguments: [spaceID, candidateID]
        ).flatMap(item(from:))
    }

    static func item(from row: Row) -> DepositedMemoryItem? {
        guard let sourceKind = MemoryItemSourceKind(rawValue: row["source_kind"] as String),
              let kind = MemoryItemKind(rawValue: row["kind"] as String),
              let difficulty = LearningMemoryCandidate.Difficulty(rawValue: row["difficulty"] as String),
              let reviewState = MemoryReviewState(rawValue: row["review_state"] as String)
        else {
            return nil
        }
        return DepositedMemoryItem(
            id: row["id"],
            spaceID: row["space_id"],
            entryID: row["entry_id"],
            sourceKind: sourceKind,
            sourceCandidateID: row["source_candidate_id"],
            kind: kind,
            text: row["text"],
            note: row["note"],
            exampleTarget: row["example_target"],
            exampleNative: row["example_native"],
            difficulty: difficulty,
            reviewState: reviewState,
            reviewRung: row["review_rung"],
            reviewDueAt: (row["review_due_at"] as Double?).map(Date.init(timeIntervalSince1970:)),
            lastReviewedAt: (row["last_reviewed_at"] as Double?).map(Date.init(timeIntervalSince1970:)),
            reviewCount: row["review_count"],
            masteredAt: (row["mastered_at"] as Double?).map(Date.init(timeIntervalSince1970:)),
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }
}
