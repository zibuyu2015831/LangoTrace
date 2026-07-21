import Foundation
import GRDB

extension AppDatabase {
    /// `language_spaces` + `app_state` (v1): the root language-space table (one
    /// space per target language, ADR-004) and the small key/value app-state
    /// store. Extracted from `AppDatabase.swift` to keep that file under the
    /// file-length budget; the registration stays in the central `migrate()`.
    static func createLanguageSpaceInfrastructure(_ db: Database) throws {
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
}
