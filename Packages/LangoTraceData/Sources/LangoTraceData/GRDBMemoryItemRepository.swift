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
            try Self.insert(item, in: db)
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

    public func depositCandidate(candidateID: String, spaceID: String) async throws -> DepositedMemoryItem? {
        let id = makeID()
        let now = clock()
        return try await databaseQueue.write { db in
            if let existing = try Self.fetchByCandidate(db, spaceID: spaceID, candidateID: candidateID) {
                return existing
            }
            guard let candidate = try Row.fetchOne(
                db,
                sql: """
                SELECT entry_id, kind, text, explanation_native, example_target, example_native, difficulty
                FROM memory_candidates
                WHERE id = ? AND space_id = ?
                """,
                arguments: [candidateID, spaceID]
            ) else {
                return nil
            }
            guard let candidateKind = LearningMemoryCandidate.Kind(rawValue: candidate["kind"] as String),
                  let difficulty = LearningMemoryCandidate.Difficulty(rawValue: candidate["difficulty"] as String)
            else {
                return nil
            }
            let item = DepositedMemoryItem(
                id: id,
                spaceID: spaceID,
                entryID: candidate["entry_id"],
                sourceKind: .candidate,
                sourceCandidateID: candidateID,
                kind: MemoryItemKind(candidateKind),
                text: candidate["text"],
                note: candidate["explanation_native"],
                exampleTarget: candidate["example_target"],
                exampleNative: candidate["example_native"],
                difficulty: difficulty,
                createdAt: now
            )
            try Self.insert(item, in: db)
            return item
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

    public func dueItems(spaceID: String, limit: Int, now: Date) async throws -> [DepositedMemoryItem] {
        guard limit > 0 else { return [] }
        return try await databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM memory_items
                WHERE space_id = ? AND soft_deleted_at IS NULL
                  AND review_state IN ('new', 'scheduled')
                  AND (review_due_at IS NULL OR review_due_at <= ?)
                ORDER BY (review_due_at IS NULL) DESC, review_due_at ASC, created_at ASC
                LIMIT ?
                """,
                arguments: [spaceID, now.timeIntervalSince1970, limit]
            ).compactMap(Self.item(from:))
        }
    }

    public func recordReviewOutcome(id: String, outcome: MemoryReviewOutcome, now: Date) async throws -> DepositedMemoryItem? {
        try await databaseQueue.write { db in
            guard let current = try Row.fetchOne(
                db,
                sql: "SELECT * FROM memory_items WHERE id = ? AND soft_deleted_at IS NULL",
                arguments: [id]
            ).flatMap(Self.item(from:)) else {
                return nil
            }
            let schedule = MemoryReviewScheduler.schedule(
                state: current.reviewState,
                rung: current.reviewRung,
                outcome: outcome,
                now: now
            )
            return try Self.applySchedule(schedule, toItemID: id, incrementReviewCount: true, lastReviewedAt: now, db: db)
        }
    }

    public func markMastered(id: String, now: Date) async throws {
        try await databaseQueue.write { db in
            _ = try Self.applySchedule(
                MemoryReviewScheduler.markMastered(now: now),
                toItemID: id,
                incrementReviewCount: false,
                lastReviewedAt: now,
                db: db
            )
        }
    }

    public func resumeReview(id: String, now: Date) async throws {
        try await databaseQueue.write { db in
            _ = try Self.applySchedule(
                MemoryReviewScheduler.resumeReview(now: now),
                toItemID: id,
                incrementReviewCount: false,
                lastReviewedAt: nil,
                db: db
            )
        }
    }

    public func memoryStatistics(spaceID: String, now: Date) async throws -> MemoryStatistics {
        let weekStart = Self.startOfWeek(for: now)
        return try await databaseQueue.read { db in
            let deposited = try Int.fetchOne(
                db,
                sql: """
                SELECT count(*) FROM memory_items
                WHERE space_id = ? AND soft_deleted_at IS NULL AND created_at >= ?
                """,
                arguments: [spaceID, weekStart.timeIntervalSince1970]
            ) ?? 0
            let due = try Int.fetchOne(
                db,
                sql: """
                SELECT count(*) FROM memory_items
                WHERE space_id = ? AND soft_deleted_at IS NULL
                  AND review_state IN ('new', 'scheduled')
                  AND (review_due_at IS NULL OR review_due_at <= ?)
                """,
                arguments: [spaceID, now.timeIntervalSince1970]
            ) ?? 0
            let mastered = try Int.fetchOne(
                db,
                sql: """
                SELECT count(*) FROM memory_items
                WHERE space_id = ? AND soft_deleted_at IS NULL AND review_state = 'mastered'
                """,
                arguments: [spaceID]
            ) ?? 0
            return MemoryStatistics(depositedThisWeek: deposited, dueCount: due, masteredCount: mastered)
        }
    }
}

private extension GRDBMemoryItemRepository {
    static func insert(_ item: DepositedMemoryItem, in db: Database) throws {
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
    }

    static func applySchedule(
        _ schedule: MemoryReviewSchedule,
        toItemID id: String,
        incrementReviewCount: Bool,
        lastReviewedAt: Date?,
        db: Database
    ) throws -> DepositedMemoryItem? {
        try db.execute(
            sql: """
            UPDATE memory_items
            SET review_state = ?,
                review_rung = ?,
                review_due_at = ?,
                mastered_at = ?,
                last_reviewed_at = COALESCE(?, last_reviewed_at),
                review_count = review_count + ?
            WHERE id = ? AND soft_deleted_at IS NULL
            """,
            arguments: [
                schedule.state.rawValue,
                schedule.rung,
                schedule.dueAt?.timeIntervalSince1970,
                schedule.masteredAt?.timeIntervalSince1970,
                lastReviewedAt?.timeIntervalSince1970,
                incrementReviewCount ? 1 : 0,
                id,
            ]
        )
        return try Row.fetchOne(
            db,
            sql: "SELECT * FROM memory_items WHERE id = ? AND soft_deleted_at IS NULL",
            arguments: [id]
        ).flatMap(item(from:))
    }

    /// Local week start (Monday 00:00 in the current calendar) for the
    /// "deposited this week" stat — computed in Swift, not SQL.
    static func startOfWeek(for now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return calendar.date(from: components) ?? now
    }

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
