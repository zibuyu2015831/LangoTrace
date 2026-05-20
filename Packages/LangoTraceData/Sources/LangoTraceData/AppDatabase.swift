import Foundation
import GRDB

public struct AppDatabase: @unchecked Sendable {
    let databaseQueue: DatabaseQueue

    public init(databaseQueue: DatabaseQueue) throws {
        self.databaseQueue = databaseQueue
        try Self.migrate(databaseQueue)
    }

    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(databaseQueue: DatabaseQueue())
    }

    public static func persistent(at databaseURL: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let database = try AppDatabase(databaseQueue: DatabaseQueue(path: databaseURL.path))
        try setFileProtectionIfAvailable(for: databaseURL)
        return database
    }
}

private extension AppDatabase {
    static func migrate(_ databaseQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_language_space_infrastructure") { db in
            try db.create(table: "language_spaces") { table in
                table.column("id", .text).primaryKey()
                table.column("native_language_code", .text).notNull()
                table.column("target_language_code", .text).notNull()
                table.column("level", .text).notNull()
                table.column("display_name", .text).notNull()
                table.column("display_name_normalized", .text).notNull()
                table.column("created_at", .double).notNull()
                table.column("updated_at", .double).notNull()
                table.column("last_opened_at", .double)
                table.column("deleted_at", .double)
            }
            try db.create(
                index: "idx_language_spaces_active_updated_at",
                on: "language_spaces",
                columns: ["deleted_at", "updated_at"]
            )
            try db.create(
                index: "idx_language_spaces_target_language",
                on: "language_spaces",
                columns: ["target_language_code"]
            )
            try db.create(
                index: "idx_language_spaces_display_name_normalized",
                on: "language_spaces",
                columns: ["display_name_normalized"]
            )
            try db.create(table: "app_state") { table in
                table.column("key", .text).primaryKey()
                table.column("value", .text)
                table.column("updated_at", .double).notNull()
            }
        }
        try migrator.migrate(databaseQueue)
    }

    static func setFileProtectionIfAvailable(for databaseURL: URL) throws {
        #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: databaseURL.path
            )
        #endif
    }
}
