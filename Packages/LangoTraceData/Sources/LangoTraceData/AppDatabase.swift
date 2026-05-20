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
            try createLanguageSpaceInfrastructure(db)
        }
        migrator.registerMigration("v2_create_ai_provider_configuration") { db in
            try createAIProviderConfiguration(db)
        }
        try migrator.migrate(databaseQueue)
    }

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

    static func createAIProviderConfiguration(_ db: Database) throws {
        try createAIProviderProfiles(db)
        try createAIProviderCredentials(db)
        try createAIProviderEndpoints(db)
        try createAIProviderCustomHeaders(db)
        try createAIProviderValidationEvents(db)
    }

    static func createAIProviderProfiles(_ db: Database) throws {
        try db.create(table: "ai_provider_profiles") { table in
            table.column("id", .text).primaryKey()
            table.column("display_name", .text).notNull()
            table.column("is_default", .boolean).notNull()
            table.column("status", .text).notNull()
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
            table.column("last_validated_at", .double)
            table.column("last_validation_status", .text)
            table.column("deleted_at", .double)
        }
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_ai_provider_profiles_active_default
        ON ai_provider_profiles(is_default)
        WHERE is_default = 1 AND deleted_at IS NULL
        """)
    }

    static func createAIProviderCredentials(_ db: Database) throws {
        try db.create(table: "ai_provider_credentials") { table in
            table.column("id", .text).primaryKey()
            table.column("profile_id", .text).notNull()
                .references("ai_provider_profiles", onDelete: .cascade)
            table.column("provider_preset_id", .text).notNull()
            table.column("kind", .text).notNull()
            table.column("label", .text).notNull()
            table.column("keychain_service", .text).notNull()
            table.column("keychain_account", .text).notNull()
            table.column("keychain_access_group", .text)
            table.column("keychain_synchronizable", .boolean).notNull()
            table.column("keychain_accessibility", .text).notNull()
            table.column("secret_presence", .text).notNull()
            table.column("cleanup_state", .text).notNull()
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
            table.column("last_resolved_at", .double)
            table.column("deleted_at", .double)
        }
        try db.create(
            index: "idx_ai_provider_credentials_keychain_reference",
            on: "ai_provider_credentials",
            columns: ["keychain_service", "keychain_account"],
            unique: true
        )
    }

    static func createAIProviderEndpoints(_ db: Database) throws {
        try db.create(table: "ai_provider_endpoints") { table in
            table.column("id", .text).primaryKey()
            table.column("profile_id", .text).notNull()
                .references("ai_provider_profiles", onDelete: .cascade)
            table.column("purpose", .text).notNull()
            table.column("is_enabled", .boolean).notNull()
            table.column("provider_preset_id", .text).notNull()
            table.column("adapter_kind", .text).notNull()
            table.column("base_url", .text).notNull()
            table.column("model_name", .text).notNull()
            table.column("credential_id", .text)
                .references("ai_provider_credentials", onDelete: .restrict)
            table.column("supports_image_input", .boolean).notNull()
            table.column("image_input_enabled", .boolean).notNull()
            table.column("request_timeout_seconds", .double)
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
            table.column("deleted_at", .double)
        }
        try db.execute(sql: """
        CREATE UNIQUE INDEX idx_ai_provider_endpoints_active_purpose
        ON ai_provider_endpoints(profile_id, purpose)
        WHERE deleted_at IS NULL
        """)
    }

    static func createAIProviderCustomHeaders(_ db: Database) throws {
        try db.create(table: "ai_provider_custom_headers") { table in
            table.column("id", .text).primaryKey()
            table.column("endpoint_id", .text).notNull()
                .references("ai_provider_endpoints", onDelete: .cascade)
            table.column("header_name", .text).notNull()
            table.column("header_name_normalized", .text).notNull()
            table.column("value_kind", .text).notNull()
            table.column("plain_value", .text)
            table.column("credential_id", .text)
                .references("ai_provider_credentials", onDelete: .restrict)
            table.column("created_at", .double).notNull()
            table.column("updated_at", .double).notNull()
        }
        try db.create(
            index: "idx_ai_provider_custom_headers_name",
            on: "ai_provider_custom_headers",
            columns: ["endpoint_id", "header_name_normalized"],
            unique: true
        )
    }

    static func createAIProviderValidationEvents(_ db: Database) throws {
        try db.create(table: "ai_provider_validation_events") { table in
            table.column("id", .text).primaryKey()
            table.column("profile_id", .text).notNull()
                .references("ai_provider_profiles", onDelete: .cascade)
            table.column("endpoint_id", .text)
                .references("ai_provider_endpoints", onDelete: .setNull)
            table.column("event_type", .text).notNull()
            table.column("status", .text).notNull()
            table.column("error_category", .text)
            table.column("provider_preset_id", .text).notNull()
            table.column("model_name", .text)
            table.column("duration_ms", .integer)
            table.column("created_at", .double).notNull()
        }
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
