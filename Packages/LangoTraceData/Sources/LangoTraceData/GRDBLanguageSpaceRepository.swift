import Foundation
import GRDB
import LangoTraceCore

public struct GRDBLanguageSpaceRepository: LanguageSpaceRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public init(
        databaseQueue: DatabaseQueue,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) throws {
        try self.init(
            database: AppDatabase(databaseQueue: databaseQueue),
            clock: clock,
            idGenerator: idGenerator
        )
    }

    public static func inMemory(
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) throws -> GRDBLanguageSpaceRepository {
        try GRDBLanguageSpaceRepository(
            database: AppDatabase.inMemory(),
            clock: clock,
            idGenerator: idGenerator
        )
    }

    public static func persistent(
        at databaseURL: URL,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) throws -> GRDBLanguageSpaceRepository {
        try GRDBLanguageSpaceRepository(
            database: AppDatabase.persistent(at: databaseURL),
            clock: clock,
            idGenerator: idGenerator
        )
    }

    public func listActiveLanguageSpaces() throws -> [LanguageSpace] {
        try databaseQueue.read { db in
            try fetchActiveSpaces(db)
        }
    }

    public func languageSpace(id: String) throws -> LanguageSpace? {
        try databaseQueue.read { db in
            try fetchSpace(id: id, db: db)
        }
    }

    public func currentLanguageSpace() throws -> LanguageSpace? {
        try databaseQueue.write { db in
            guard let currentID = try currentLanguageSpaceID(db) else {
                return try repairCurrentLanguageSpaceID(using: nil, db: db)
            }
            guard let current = try fetchSpace(id: currentID, db: db) else {
                return try repairCurrentLanguageSpaceID(using: currentID, db: db)
            }

            guard current.isActive else {
                return try repairCurrentLanguageSpaceID(using: currentID, db: db)
            }

            return current
        }
    }

    public func createLanguageSpace(input: CreateLanguageSpaceInput) throws -> LanguageSpace {
        let normalized = try input.validated()
        return try databaseQueue.write { db in
            let now = clock()
            let space = LanguageSpace(
                id: idGenerator(),
                nativeLanguageCode: normalized.nativeLanguageCode,
                targetLanguageCode: normalized.targetLanguageCode,
                level: normalized.level,
                displayName: normalized.displayName,
                displayNameNormalized: normalized.displayNameNormalized,
                createdAt: now,
                updatedAt: now,
                lastOpenedAt: now,
                deletedAt: nil
            )
            try insert(space, db: db)
            try writeCurrentLanguageSpaceID(space.id, at: now, db: db)
            return space
        }
    }

    public func updateLanguageSpace(id: String, input: UpdateLanguageSpaceInput) throws -> LanguageSpace {
        let normalized = try input.validated()
        return try databaseQueue.write { db in
            guard let existing = try fetchSpace(id: id, db: db) else {
                throw LanguageSpaceError.notFound
            }
            guard existing.isActive else {
                throw LanguageSpaceError.deleted
            }

            let now = clock()
            try db.execute(
                sql: """
                UPDATE language_spaces
                SET native_language_code = ?,
                    target_language_code = ?,
                    level = ?,
                    display_name = ?,
                    display_name_normalized = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    normalized.nativeLanguageCode,
                    normalized.targetLanguageCode,
                    normalized.level.rawValue,
                    normalized.displayName,
                    normalized.displayNameNormalized,
                    now.timeIntervalSince1970,
                    id,
                ]
            )
            guard let updated = try fetchSpace(id: id, db: db) else {
                throw LanguageSpaceError.notFound
            }
            return updated
        }
    }

    public func selectCurrentLanguageSpace(id: String) throws -> LanguageSpace {
        try databaseQueue.write { db in
            guard let space = try fetchSpace(id: id, db: db) else {
                throw LanguageSpaceError.notFound
            }
            guard space.isActive else {
                throw LanguageSpaceError.deleted
            }

            let now = clock()
            try db.execute(
                sql: "UPDATE language_spaces SET last_opened_at = ?, updated_at = ? WHERE id = ?",
                arguments: [now.timeIntervalSince1970, now.timeIntervalSince1970, id]
            )
            try writeCurrentLanguageSpaceID(id, at: now, db: db)
            guard let selected = try fetchSpace(id: id, db: db) else {
                throw LanguageSpaceError.notFound
            }
            return selected
        }
    }

    public func deleteLanguageSpace(id: String) throws -> LanguageSpaceDeletionResult {
        try databaseQueue.write { db in
            guard let space = try fetchSpace(id: id, db: db) else {
                throw LanguageSpaceError.notFound
            }
            guard space.isActive else {
                throw LanguageSpaceError.deleted
            }

            let now = clock()
            try db.execute(
                sql: "UPDATE language_spaces SET deleted_at = ?, updated_at = ? WHERE id = ?",
                arguments: [now.timeIntervalSince1970, now.timeIntervalSince1970, id]
            )
            let currentID = try currentLanguageSpaceID(db)
            let fallback = if currentID == id {
                try latestActiveSpace(db, excludingID: id)
            } else {
                try fetchSpace(id: currentID, db: db)
            }
            if currentID == id {
                try writeCurrentLanguageSpaceID(fallback?.id, at: now, db: db)
            }
            let activeCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM language_spaces WHERE deleted_at IS NULL"
            ) ?? 0
            return LanguageSpaceDeletionResult(
                deletedSpaceID: id,
                fallbackCurrentSpace: fallback,
                remainingActiveCount: activeCount
            )
        }
    }

    public func duplicateNameExists(displayName: String, excludingID: String?) throws -> Bool {
        let normalized = CreateLanguageSpaceInput.normalizedDisplayName(displayName)
        return try databaseQueue.read { db in
            let count = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM language_spaces
                WHERE deleted_at IS NULL
                  AND display_name_normalized = ?
                  AND (? IS NULL OR id != ?)
                """,
                arguments: [normalized, excludingID, excludingID]
            ) ?? 0
            return count > 0
        }
    }
}

private extension GRDBLanguageSpaceRepository {
    func insert(_ space: LanguageSpace, db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces (
                id, native_language_code, target_language_code, level,
                display_name, display_name_normalized, created_at, updated_at,
                last_opened_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                space.id,
                space.nativeLanguageCode,
                space.targetLanguageCode,
                space.level.rawValue,
                space.displayName,
                space.displayNameNormalized,
                space.createdAt.timeIntervalSince1970,
                space.updatedAt.timeIntervalSince1970,
                space.lastOpenedAt?.timeIntervalSince1970,
                space.deletedAt?.timeIntervalSince1970,
            ]
        )
    }

    func fetchActiveSpaces(_ db: Database) throws -> [LanguageSpace] {
        try Row.fetchAll(
            db,
            sql: """
            SELECT *
            FROM language_spaces
            WHERE deleted_at IS NULL
            ORDER BY COALESCE(last_opened_at, updated_at) DESC, updated_at DESC
            """
        ).map(languageSpace(from:))
    }

    func latestActiveSpace(_ db: Database, excludingID: String?) throws -> LanguageSpace? {
        try Row.fetchOne(
            db,
            sql: """
            SELECT *
            FROM language_spaces
            WHERE deleted_at IS NULL
              AND (? IS NULL OR id != ?)
            ORDER BY COALESCE(last_opened_at, updated_at) DESC, updated_at DESC
            LIMIT 1
            """,
            arguments: [excludingID, excludingID]
        ).map(languageSpace(from:))
    }

    func fetchSpace(id: String?, db: Database) throws -> LanguageSpace? {
        guard let id else { return nil }
        return try Row.fetchOne(
            db,
            sql: "SELECT * FROM language_spaces WHERE id = ?",
            arguments: [id]
        ).map(languageSpace(from:))
    }

    func currentLanguageSpaceID(_ db: Database) throws -> String? {
        try String.fetchOne(
            db,
            sql: "SELECT value FROM app_state WHERE key = ?",
            arguments: ["current_language_space_id"]
        )
    }

    func writeCurrentLanguageSpaceID(_ id: String?, at date: Date, db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO app_state (key, value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                updated_at = excluded.updated_at
            """,
            arguments: ["current_language_space_id", id, date.timeIntervalSince1970]
        )
    }

    func repairCurrentLanguageSpaceID(using invalidID: String?, db: Database) throws -> LanguageSpace? {
        let fallback = try latestActiveSpace(db, excludingID: invalidID)
        try writeCurrentLanguageSpaceID(fallback?.id, at: clock(), db: db)
        return fallback
    }

    func languageSpace(from row: Row) -> LanguageSpace {
        LanguageSpace(
            id: row["id"],
            nativeLanguageCode: row["native_language_code"],
            targetLanguageCode: row["target_language_code"],
            level: LanguageLevel(rawValue: row["level"] as String) ?? .b1,
            displayName: row["display_name"],
            displayNameNormalized: row["display_name_normalized"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"]),
            lastOpenedAt: date(from: row["last_opened_at"]),
            deletedAt: date(from: row["deleted_at"])
        )
    }

    func date(from value: Double?) -> Date? {
        value.map(Date.init(timeIntervalSince1970:))
    }
}
