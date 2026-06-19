import Foundation
import GRDB
import LangoTraceCore

public struct GRDBAIProviderConfigurationRepository: AIProviderConfigurationRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let diagnosticLogger: any DiagnosticLogging
    private let clock: @Sendable () -> Date

    public init(
        database: AppDatabase,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger(),
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        databaseQueue = database.databaseQueue
        self.diagnosticLogger = diagnosticLogger
        self.clock = clock
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
        try await saveProfile(profile, ttsSettings: nil, ttsVoiceProfiles: [])
    }

    public func saveProfile(
        _ profile: AIProviderConfigurationProfile,
        ttsSettings: TTSProviderSettings?,
        ttsVoiceProfiles: [TTSVoiceProfile]
    ) async throws {
        try await databaseQueue.write { db in
            try upsert(profile, db: db)

            // Deleting endpoints cascades into tts_audio_artifacts extension rows.
            // Invalidate the media_artifacts master rows first so they cannot linger
            // as active orphans that block same-key TTS cache rebuilds.
            try invalidateTTSMediaArtifacts(profileID: profile.id, db: db)
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
            if let ttsSettings {
                try insert(ttsSettings, db: db)
            }
            for voiceProfile in ttsVoiceProfiles {
                try insert(voiceProfile, db: db)
            }
        }
    }

    public func loadTTSSettings(endpointID: AIProviderEndpointID) async throws -> TTSProviderSettings? {
        try await GRDBTTSProviderSettingsRepository(databaseQueue: databaseQueue)
            .loadSettings(endpointID: endpointID)
    }

    public func loadTTSVoiceProfile(
        endpointID: AIProviderEndpointID,
        languageCode: String
    ) async throws -> TTSVoiceProfile? {
        try await GRDBTTSProviderSettingsRepository(databaseQueue: databaseQueue)
            .loadVoiceProfile(endpointID: endpointID, languageCode: languageCode)
    }

    public func recordTTSVoiceProfileProbeOutcome(
        _ event: AIProviderValidationEvent,
        languageCode: String
    ) async throws {
        try await GRDBTTSProviderSettingsRepository(databaseQueue: databaseQueue)
            .recordTTSVoiceProfileProbeOutcome(event, languageCode: languageCode)
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
                arguments: [state.rawValue, clock().timeIntervalSince1970, credentialID]
            )
        }
    }

    public func recordValidationEvent(_ event: AIProviderValidationEvent) async throws {
        try await databaseQueue.write { db in
            try insert(event, db: db)
        }
    }

    public func recordValidationOutcome(_ event: AIProviderValidationEvent) async throws {
        try await databaseQueue.write { db in
            try insert(event, db: db)
            try db.execute(
                sql: """
                UPDATE ai_provider_profiles
                SET last_validated_at = ?, last_validation_status = ?, updated_at = ?
                WHERE id = ? AND deleted_at IS NULL
                """,
                arguments: [
                    event.createdAt.timeIntervalSince1970,
                    event.status.rawValue,
                    event.createdAt.timeIntervalSince1970,
                    event.profileID,
                ]
            )
        }
    }

    public func recordEndpointValidationOutcome(_ outcome: AIProviderEndpointValidationOutcome) async throws {
        try await databaseQueue.write { db in
            try insert(outcome.event, db: db)
            guard let endpointID = outcome.event.endpointID else {
                return
            }

            let successfulFingerprint: String? = outcome.event.status == .succeeded
                ? outcome.configurationFingerprint
                : nil
            if let successfulFingerprint {
                try db.execute(
                    sql: """
                    UPDATE ai_provider_endpoints
                    SET last_validated_at = ?,
                        last_validation_status = ?,
                        last_validation_error_category = ?,
                        last_successful_configuration_fingerprint = ?,
                        updated_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                    """,
                    arguments: [
                        outcome.event.createdAt.timeIntervalSince1970,
                        outcome.event.status.rawValue,
                        outcome.event.errorCategory?.rawValue,
                        successfulFingerprint,
                        outcome.event.createdAt.timeIntervalSince1970,
                        endpointID,
                    ]
                )
            } else {
                try db.execute(
                    sql: """
                    UPDATE ai_provider_endpoints
                    SET last_validated_at = ?,
                        last_validation_status = ?,
                        last_validation_error_category = ?,
                        updated_at = ?
                    WHERE id = ? AND deleted_at IS NULL
                    """,
                    arguments: [
                        outcome.event.createdAt.timeIntervalSince1970,
                        outcome.event.status.rawValue,
                        outcome.event.errorCategory?.rawValue,
                        outcome.event.createdAt.timeIntervalSince1970,
                        endpointID,
                    ]
                )
            }
        }
    }
}

private extension GRDBAIProviderConfigurationRepository {
    func invalidateTTSMediaArtifacts(profileID: AIProviderProfileID, db: Database) throws {
        try db.execute(
            sql: """
            UPDATE media_artifacts
            SET invalidated_at = ?
            WHERE invalidated_at IS NULL
              AND id IN (
                SELECT tts_audio_artifacts.artifact_id
                FROM tts_audio_artifacts
                JOIN ai_provider_endpoints
                  ON ai_provider_endpoints.id = tts_audio_artifacts.tts_endpoint_id
                WHERE ai_provider_endpoints.profile_id = ?
              )
            """,
            arguments: [clock().timeIntervalSince1970, profileID]
        )
    }

    func insert(_ event: AIProviderValidationEvent, db: Database) throws {
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
                last_validated_at, last_validation_status, last_validation_error_category,
                last_successful_configuration_fingerprint, created_at, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                endpoint.lastValidatedAt?.timeIntervalSince1970,
                endpoint.lastValidationStatus?.rawValue,
                endpoint.lastValidationErrorCategory?.rawValue,
                endpoint.lastSuccessfulConfigurationFingerprint,
                endpoint.createdAt.timeIntervalSince1970,
                endpoint.updatedAt.timeIntervalSince1970,
                nil,
            ]
        )
    }

    func insert(_ settings: TTSProviderSettings, db: Database) throws {
        let now = clock().timeIntervalSince1970
        try db.execute(
            sql: """
            INSERT INTO ai_provider_tts_settings (
                endpoint_id, tts_adapter_kind, created_at, updated_at
            ) VALUES (?, ?, ?, ?)
            """,
            arguments: [settings.endpointID, settings.adapterKind.rawValue, now, now]
        )
    }

    func insert(_ profile: TTSVoiceProfile, db: Database) throws {
        let data = try JSONEncoder().encode(profile.providerParameters)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        let now = clock().timeIntervalSince1970
        try db.execute(
            sql: """
            INSERT INTO ai_provider_tts_voice_profiles (
                id, endpoint_id, language_code, tts_adapter_kind, model_name,
                voice_id, voice_display_name, output_format, sample_rate,
                speed, volume, pitch, style_prompt, instructions, streaming_mode,
                provider_parameters_json, configuration_fingerprint,
                last_successful_configuration_fingerprint, last_test_status,
                last_tested_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                profile.id,
                profile.endpointID,
                profile.languageCode,
                profile.adapterKind.rawValue,
                profile.modelName,
                profile.voiceID,
                profile.voiceDisplayName,
                profile.outputFormat.rawValue,
                profile.sampleRate,
                profile.speed,
                profile.volume,
                profile.pitch,
                profile.stylePrompt,
                profile.instructions,
                profile.streamingMode,
                json,
                profile.configurationFingerprint,
                profile.lastSuccessfulConfigurationFingerprint,
                profile.lastTestStatus.rawValue,
                profile.lastTestedAt?.timeIntervalSince1970,
                now,
                now,
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
            status: StoredEnumDecoding.decode(
                AIProviderProfileStatus.self,
                from: row["status"] as String,
                fallback: .incomplete,
                context: "ai_provider_profiles.status",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
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
            purpose: StoredEnumDecoding.decode(
                AIProviderEndpointPurpose.self,
                from: row["purpose"] as String,
                fallback: .textGeneration,
                context: "ai_provider_endpoints.purpose",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            isEnabled: row["is_enabled"],
            providerPresetID: row["provider_preset_id"],
            adapterKind: StoredEnumDecoding.decode(
                AIProviderAdapterKind.self,
                from: row["adapter_kind"] as String,
                fallback: .openAICompatibleChat,
                context: "ai_provider_endpoints.adapter_kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
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
            updatedAt: date(row["updated_at"]),
            lastValidatedAt: optionalDate(row["last_validated_at"]),
            lastValidationStatus: optionalValidationStatus(row["last_validation_status"]),
            lastValidationErrorCategory: optionalValidationErrorCategory(row["last_validation_error_category"]),
            lastSuccessfulConfigurationFingerprint: row["last_successful_configuration_fingerprint"]
        )
    }

    func credential(from row: Row) -> AIProviderCredentialMetadata {
        AIProviderCredentialMetadata(
            id: row["id"],
            profileID: row["profile_id"],
            providerPresetID: row["provider_preset_id"],
            kind: StoredEnumDecoding.decode(
                AIProviderCredentialKind.self,
                from: row["kind"] as String,
                fallback: .apiKey,
                context: "ai_provider_credentials.kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            label: row["label"],
            keychainService: row["keychain_service"],
            keychainAccessGroup: row["keychain_access_group"],
            keychainSynchronizable: row["keychain_synchronizable"],
            keychainAccessibility: row["keychain_accessibility"],
            secretPresence: StoredEnumDecoding.decode(
                AIProviderSecretPresence.self,
                from: row["secret_presence"] as String,
                fallback: .unknown,
                context: "ai_provider_credentials.secret_presence",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            cleanupState: StoredEnumDecoding.decode(
                AIProviderCredentialCleanupState.self,
                from: row["cleanup_state"] as String,
                fallback: .active,
                context: "ai_provider_credentials.cleanup_state",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
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

    func optionalValidationErrorCategory(_ value: String?) -> AIProviderValidationErrorCategory? {
        value.flatMap(AIProviderValidationErrorCategory.init(rawValue:))
    }
}
