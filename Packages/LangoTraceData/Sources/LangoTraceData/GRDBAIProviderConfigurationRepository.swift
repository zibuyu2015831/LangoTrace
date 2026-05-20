import Foundation
import GRDB
import LangoTraceCore

public struct GRDBAIProviderConfigurationRepository: AIProviderConfigurationRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue

    public init(database: AppDatabase) {
        databaseQueue = database.databaseQueue
    }

    public func loadDefaultProfile() async throws -> AIProviderConfigurationProfile? {
        try await databaseQueue.read { db in
            guard let profileRow = try Row.fetchOne(
                db,
                sql: """
                SELECT *
                FROM ai_provider_profiles
                WHERE is_default = 1 AND deleted_at IS NULL
                LIMIT 1
                """
            ) else {
                return nil
            }
            let profileID: String = profileRow["id"]
            let endpoints = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM ai_provider_endpoints
                WHERE profile_id = ? AND deleted_at IS NULL
                ORDER BY purpose
                """,
                arguments: [profileID]
            ).map(endpoint(from:))
            let credentials = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM ai_provider_credentials
                WHERE profile_id = ? AND deleted_at IS NULL
                ORDER BY id
                """,
                arguments: [profileID]
            ).map(credential(from:))

            return profile(from: profileRow, endpoints: endpoints, credentials: credentials)
        }
    }

    public func saveProfile(_ profile: AIProviderConfigurationProfile) async throws {
        try await databaseQueue.write { db in
            try upsert(profile, db: db)

            try db.execute(
                sql: "DELETE FROM ai_provider_endpoints WHERE profile_id = ?",
                arguments: [profile.id]
            )
            try db.execute(
                sql: "DELETE FROM ai_provider_credentials WHERE profile_id = ?",
                arguments: [profile.id]
            )

            for credential in profile.credentials {
                try insert(credential, db: db)
            }
            for endpoint in profile.endpoints {
                try insert(endpoint, db: db)
            }
        }
    }

    public func markCredentialState(
        _ state: AIProviderSecretPresence,
        credentialID: AIProviderCredentialID
    ) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE ai_provider_credentials
                SET secret_presence = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [state.rawValue, Date().timeIntervalSince1970, credentialID]
            )
        }
    }

    public func recordValidationEvent(_ event: AIProviderValidationEvent) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO ai_provider_validation_events (
                    id, profile_id, endpoint_id, event_type, status, error_category,
                    provider_preset_id, model_name, duration_ms, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    event.id,
                    event.profileID,
                    event.endpointID,
                    event.eventType.rawValue,
                    event.status.rawValue,
                    event.errorCategory?.rawValue,
                    event.providerPresetID,
                    event.modelName,
                    event.durationMilliseconds,
                    event.createdAt.timeIntervalSince1970,
                ]
            )
        }
    }
}

private extension GRDBAIProviderConfigurationRepository {
    func upsert(_ profile: AIProviderConfigurationProfile, db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO ai_provider_profiles (
                id, display_name, is_default, status, created_at, updated_at,
                last_validated_at, last_validation_status, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                display_name = excluded.display_name,
                is_default = excluded.is_default,
                status = excluded.status,
                updated_at = excluded.updated_at,
                last_validated_at = excluded.last_validated_at,
                last_validation_status = excluded.last_validation_status,
                deleted_at = excluded.deleted_at
            """,
            arguments: [
                profile.id,
                profile.displayName,
                profile.isDefault,
                profile.status.rawValue,
                profile.createdAt.timeIntervalSince1970,
                profile.updatedAt.timeIntervalSince1970,
                profile.lastValidatedAt?.timeIntervalSince1970,
                profile.lastValidationStatus?.rawValue,
                profile.deletedAt?.timeIntervalSince1970,
            ]
        )
    }

    func insert(_ credential: AIProviderCredentialMetadata, db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO ai_provider_credentials (
                id, profile_id, provider_preset_id, kind, label,
                keychain_service, keychain_account, keychain_access_group,
                keychain_synchronizable, keychain_accessibility, secret_presence,
                cleanup_state, created_at, updated_at, last_resolved_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                credential.id,
                credential.profileID,
                credential.providerPresetID,
                credential.kind.rawValue,
                credential.label,
                credential.keychainService,
                credential.keychainAccount,
                credential.keychainAccessGroup,
                credential.keychainSynchronizable,
                credential.keychainAccessibility,
                credential.secretPresence.rawValue,
                credential.cleanupState.rawValue,
                credential.createdAt.timeIntervalSince1970,
                credential.updatedAt.timeIntervalSince1970,
                credential.lastResolvedAt?.timeIntervalSince1970,
                credential.deletedAt?.timeIntervalSince1970,
            ]
        )
    }

    func insert(_ endpoint: AIProviderEndpointConfiguration, db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO ai_provider_endpoints (
                id, profile_id, purpose, is_enabled, provider_preset_id,
                adapter_kind, base_url, model_name, credential_id,
                supports_image_input, image_input_enabled, request_timeout_seconds,
                created_at, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                endpoint.id,
                endpoint.profileID,
                endpoint.purpose.rawValue,
                endpoint.isEnabled,
                endpoint.providerPresetID,
                endpoint.adapterKind.rawValue,
                endpoint.baseURL,
                endpoint.modelName,
                endpoint.credentialID,
                endpoint.supportsImageInput,
                endpoint.imageInputEnabled,
                endpoint.requestTimeoutSeconds,
                endpoint.createdAt.timeIntervalSince1970,
                endpoint.updatedAt.timeIntervalSince1970,
                nil,
            ]
        )
    }

    func profile(
        from row: Row,
        endpoints: [AIProviderEndpointConfiguration],
        credentials: [AIProviderCredentialMetadata]
    ) -> AIProviderConfigurationProfile {
        AIProviderConfigurationProfile(
            id: row["id"],
            displayName: row["display_name"],
            isDefault: row["is_default"],
            status: AIProviderProfileStatus(rawValue: row["status"] as String) ?? .incomplete,
            createdAt: date(row["created_at"]),
            updatedAt: date(row["updated_at"]),
            lastValidatedAt: optionalDate(row["last_validated_at"]),
            lastValidationStatus: optionalValidationStatus(row["last_validation_status"]),
            deletedAt: optionalDate(row["deleted_at"]),
            endpoints: endpoints,
            credentials: credentials
        )
    }

    func endpoint(from row: Row) throws -> AIProviderEndpointConfiguration {
        let input = AIProviderEndpointInput(
            id: row["id"],
            profileID: row["profile_id"],
            purpose: AIProviderEndpointPurpose(rawValue: row["purpose"] as String) ?? .textGeneration,
            isEnabled: row["is_enabled"],
            providerPresetID: row["provider_preset_id"],
            adapterKind: AIProviderAdapterKind(rawValue: row["adapter_kind"] as String) ?? .openAICompatibleChat,
            baseURL: row["base_url"],
            modelName: row["model_name"],
            credentialID: row["credential_id"],
            supportsImageInput: row["supports_image_input"],
            imageInputEnabled: row["image_input_enabled"],
            requestTimeoutSeconds: row["request_timeout_seconds"]
        )
        return try AIProviderEndpointConfiguration(
            input: input,
            createdAt: date(row["created_at"]),
            updatedAt: date(row["updated_at"])
        )
    }

    func credential(from row: Row) -> AIProviderCredentialMetadata {
        AIProviderCredentialMetadata(
            id: row["id"],
            profileID: row["profile_id"],
            providerPresetID: row["provider_preset_id"],
            kind: AIProviderCredentialKind(rawValue: row["kind"] as String) ?? .apiKey,
            label: row["label"],
            keychainService: row["keychain_service"],
            keychainAccessGroup: row["keychain_access_group"],
            keychainSynchronizable: row["keychain_synchronizable"],
            keychainAccessibility: row["keychain_accessibility"],
            secretPresence: AIProviderSecretPresence(rawValue: row["secret_presence"] as String) ?? .unknown,
            cleanupState: AIProviderCredentialCleanupState(rawValue: row["cleanup_state"] as String) ?? .active,
            createdAt: date(row["created_at"]),
            updatedAt: date(row["updated_at"]),
            lastResolvedAt: optionalDate(row["last_resolved_at"]),
            deletedAt: optionalDate(row["deleted_at"])
        )
    }

    func date(_ value: Double) -> Date {
        Date(timeIntervalSince1970: value)
    }

    func optionalDate(_ value: Double?) -> Date? {
        value.map(Date.init(timeIntervalSince1970:))
    }

    func optionalValidationStatus(_ value: String?) -> AIProviderValidationStatus? {
        value.flatMap(AIProviderValidationStatus.init(rawValue:))
    }
}
