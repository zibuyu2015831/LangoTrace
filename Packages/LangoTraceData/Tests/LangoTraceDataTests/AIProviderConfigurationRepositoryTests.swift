import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Test("AI provider repository saves and loads non secret default profile")
func aiProviderRepositorySavesAndLoadsNonSecretDefaultProfile() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try defaultProfile()

    try await repository.saveProfile(profile)

    let loaded = try await repository.loadDefaultProfile()
    let loadedPurposes = loaded?.endpoints.map(\.purpose)
    #expect(loaded?.id == "profile-1")
    #expect(loadedPurposes == [.textGeneration])
    #expect(loaded?.credentials.first?.keychainAccount == "ai-provider-credential:credential-1:api_key")

    let credentialColumns = try await database.databaseQueue.read { db in
        try Row.fetchAll(db, sql: "PRAGMA table_info(ai_provider_credentials)")
            .map { $0["name"] as String }
    }
    #expect(!credentialColumns.contains("api_key_plaintext"))
    #expect(!credentialColumns.contains("api_key_ciphertext"))
    #expect(!credentialColumns.contains("secret_hash"))
    #expect(!credentialColumns.contains("secret_last_four"))
}

@Test("AI provider repository updates credential presence and records non secret validation events")
func aiProviderRepositoryUpdatesCredentialPresenceAndRecordsValidationEvents() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try defaultProfile()
    try await repository.saveProfile(profile)

    try await repository.markCredentialState(.missing, credentialID: "credential-1")
    let loaded = try await repository.loadDefaultProfile()
    #expect(loaded?.credentials.first?.secretPresence == .missing)

    try await repository.recordValidationEvent(
        AIProviderValidationEvent(
            id: "event-1",
            profileID: "profile-1",
            endpointID: "endpoint-1",
            eventType: .credentialValidation,
            status: .failed,
            errorCategory: .missingCredential,
            providerPresetID: "openai",
            modelName: "gpt-5.2",
            durationMilliseconds: 12,
            createdAt: Date(timeIntervalSince1970: 120)
        )
    )

    let storedEvent = try database.databaseQueue.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM ai_provider_validation_events WHERE id = ?", arguments: ["event-1"])
    }
    #expect(storedEvent?["error_category"] as String? == "missing_credential")
    #expect(storedEvent?["duration_ms"] as Int? == 12)
}

@Test("AI provider repository records synthetic validation outcome and updates profile summary")
func aiProviderRepositoryRecordsSyntheticValidationOutcomeAndUpdatesProfileSummary() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try defaultProfile()
    try await repository.saveProfile(profile)

    try await repository.recordValidationOutcome(
        AIProviderValidationEvent(
            id: "event-synthetic-1",
            profileID: "profile-1",
            endpointID: "endpoint-1",
            eventType: .syntheticTest,
            status: .failed,
            errorCategory: .invalidResponse,
            providerPresetID: "openai",
            modelName: "gpt-5.2",
            durationMilliseconds: 44,
            createdAt: Date(timeIntervalSince1970: 180)
        )
    )

    let loaded = try await repository.loadDefaultProfile()
    #expect(loaded?.lastValidatedAt == Date(timeIntervalSince1970: 180))
    #expect(loaded?.lastValidationStatus == .failed)

    let storedEvent = try database.databaseQueue.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM ai_provider_validation_events WHERE id = ?", arguments: ["event-synthetic-1"])
    }
    #expect(storedEvent?["event_type"] as String? == "synthetic_test")
    #expect(storedEvent?["error_category"] as String? == "invalid_response")
}

@Test("AI provider repository records endpoint scoped validation without changing profile summary")
func aiProviderRepositoryRecordsEndpointScopedValidationWithoutChangingProfileSummary() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try embeddingProfile()
    try await repository.saveProfile(profile)

    try await repository.recordEndpointValidationOutcome(
        AIProviderEndpointValidationOutcome(
            event: AIProviderValidationEvent(
                id: "event-embedding-1",
                profileID: "profile-1",
                endpointID: "endpoint-embedding",
                eventType: .syntheticTest,
                status: .succeeded,
                errorCategory: nil,
                providerPresetID: "openai",
                modelName: "text-embedding-3-small",
                durationMilliseconds: 88,
                createdAt: Date(timeIntervalSince1970: 240)
            ),
            configurationFingerprint: "embedding-fingerprint-1"
        )
    )

    let loaded = try await repository.loadDefaultProfile()
    let embeddingEndpoint = loaded?.endpoints.first { $0.purpose == .embedding }
    #expect(loaded?.lastValidatedAt == nil)
    #expect(loaded?.lastValidationStatus == nil)
    #expect(embeddingEndpoint?.lastValidatedAt == Date(timeIntervalSince1970: 240))
    #expect(embeddingEndpoint?.lastValidationStatus == .succeeded)
    #expect(embeddingEndpoint?.lastValidationErrorCategory == nil)
    #expect(embeddingEndpoint?.lastSuccessfulConfigurationFingerprint == "embedding-fingerprint-1")

    let storedEvent = try database.databaseQueue.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM ai_provider_validation_events WHERE id = ?", arguments: ["event-embedding-1"])
    }
    #expect(storedEvent?["endpoint_id"] as String? == "endpoint-embedding")
    #expect(storedEvent?["event_type"] as String? == "synthetic_test")
}

@Test("AI provider repository stores failed endpoint scoped validation without successful fingerprint")
func aiProviderRepositoryStoresFailedEndpointScopedValidationWithoutSuccessfulFingerprint() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try embeddingProfile()
    try await repository.saveProfile(profile)

    try await repository.recordEndpointValidationOutcome(
        AIProviderEndpointValidationOutcome(
            event: AIProviderValidationEvent(
                id: "event-embedding-failed",
                profileID: "profile-1",
                endpointID: "endpoint-embedding",
                eventType: .syntheticTest,
                status: .failed,
                errorCategory: .invalidEmbeddingResponse,
                providerPresetID: "openai",
                modelName: "text-embedding-3-small",
                durationMilliseconds: 90,
                createdAt: Date(timeIntervalSince1970: 260)
            ),
            configurationFingerprint: "embedding-fingerprint-1"
        )
    )

    let loaded = try await repository.loadDefaultProfile()
    let embeddingEndpoint = loaded?.endpoints.first { $0.purpose == .embedding }
    #expect(embeddingEndpoint?.lastValidationStatus == .failed)
    #expect(embeddingEndpoint?.lastValidationErrorCategory == .invalidEmbeddingResponse)
    #expect(embeddingEndpoint?.lastSuccessfulConfigurationFingerprint == nil)
}

@Test("AI provider repository saves TTS settings in same profile transaction")
func aiProviderRepositorySavesTTSSettingsInSameProfileTransaction() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try ttsProfile()
    let voice = try TTSVoiceProfile.make(
        id: "voice-en",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3
    )

    try await repository.saveProfile(
        profile,
        ttsSettings: TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
        ttsVoiceProfiles: [voice]
    )

    let stored = try await database.databaseQueue.read { db in
        try Row.fetchOne(
            db,
            sql: """
            SELECT settings.tts_adapter_kind, voice.voice_id, voice.language_code
            FROM ai_provider_tts_settings settings
            JOIN ai_provider_tts_voice_profiles voice ON voice.endpoint_id = settings.endpoint_id
            WHERE settings.endpoint_id = ?
            """,
            arguments: ["endpoint-tts"]
        )
    }

    #expect(stored?["tts_adapter_kind"] as String? == "openai_audio_speech")
    #expect(stored?["voice_id"] as String? == "coral")
    #expect(stored?["language_code"] as String? == "en")
}

@Test("AI provider repository can resave TTS settings for the same endpoint")
func aiProviderRepositoryCanResaveTTSSettingsForSameEndpoint() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try ttsProfile()
    let firstVoice = try TTSVoiceProfile.make(
        id: "voice-en-1",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "coral",
        outputFormat: .mp3
    )
    let updatedVoice = try TTSVoiceProfile.make(
        id: "voice-en-2",
        endpointID: "endpoint-tts",
        languageCode: "en",
        adapterKind: .openAIAudioSpeech,
        modelName: "gpt-4o-mini-tts",
        voiceID: "nova",
        outputFormat: .wav
    )

    try await repository.saveProfile(
        profile,
        ttsSettings: TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
        ttsVoiceProfiles: [firstVoice]
    )
    try await repository.saveProfile(
        profile,
        ttsSettings: TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
        ttsVoiceProfiles: [updatedVoice]
    )

    let loaded = try await repository.loadTTSVoiceProfile(endpointID: "endpoint-tts", languageCode: "en")

    #expect(loaded?.id == "voice-en-2")
    #expect(loaded?.voiceID == "nova")
    #expect(loaded?.outputFormat == .wav)
}

@Test("AI provider migration enforces active default purpose and Keychain uniqueness")
func aiProviderMigrationEnforcesActiveDefaultPurposeAndKeychainUniqueness() async throws {
    let database = try AppDatabase.inMemory()
    let repository = GRDBAIProviderConfigurationRepository(database: database)
    let profile = try defaultProfile()

    try await repository.saveProfile(profile)

    #expect(throws: DatabaseError.self) {
        try database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO ai_provider_profiles (
                    id, display_name, is_default, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: ["profile-2", "Second", 1, "configured", 200, 200]
            )
        }
    }

    #expect(throws: DatabaseError.self) {
        try database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO ai_provider_endpoints (
                    id, profile_id, purpose, is_enabled, provider_preset_id,
                    adapter_kind, base_url, model_name, credential_id,
                    supports_image_input, image_input_enabled, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "endpoint-2", "profile-1", "text_generation", 1, "openai",
                    "openai_responses", "https://api.openai.com/v1", "gpt-5.2",
                    "credential-1", 1, 0, 200, 200,
                ]
            )
        }
    }

    #expect(throws: DatabaseError.self) {
        try database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO ai_provider_credentials (
                    id, profile_id, provider_preset_id, kind, label,
                    keychain_service, keychain_account, keychain_synchronizable,
                    keychain_accessibility, secret_presence, cleanup_state,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    "credential-2", "profile-1", "openai", "api_key", "Duplicate",
                    "com.langotrace.ai-provider", "ai-provider-credential:credential-1:api_key",
                    0, "when_unlocked_this_device_only", "present", "active", 200, 200,
                ]
            )
        }
    }
}

private func defaultProfile() throws -> AIProviderConfigurationProfile {
    let now = Date(timeIntervalSince1970: 100)
    let endpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-1",
            profileID: "profile-1",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-5.2",
            credentialID: "credential-1",
            supportsImageInput: true,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
    let credential = AIProviderCredentialMetadata(
        id: "credential-1",
        profileID: "profile-1",
        providerPresetID: "openai",
        kind: .apiKey,
        label: "OpenAI API Key",
        secretPresence: .present,
        createdAt: now,
        updatedAt: now
    )
    return AIProviderConfigurationProfile(
        id: "profile-1",
        displayName: "Default AI Provider",
        isDefault: true,
        status: .configured,
        createdAt: now,
        updatedAt: now,
        endpoints: [endpoint],
        credentials: [credential]
    )
}

private func embeddingProfile() throws -> AIProviderConfigurationProfile {
    let now = Date(timeIntervalSince1970: 100)
    let textEndpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-text",
            profileID: "profile-1",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-5.2",
            credentialID: "credential-1",
            supportsImageInput: true,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
    let embeddingEndpoint = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-embedding",
            profileID: "profile-1",
            purpose: .embedding,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "text-embedding-3-small",
            credentialID: "credential-1",
            supportsImageInput: false,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
    let credential = AIProviderCredentialMetadata(
        id: "credential-1",
        profileID: "profile-1",
        providerPresetID: "openai",
        kind: .apiKey,
        label: "OpenAI API Key",
        secretPresence: .present,
        createdAt: now,
        updatedAt: now
    )
    return AIProviderConfigurationProfile(
        id: "profile-1",
        displayName: "Default AI Provider",
        isDefault: true,
        status: .configured,
        createdAt: now,
        updatedAt: now,
        endpoints: [textEndpoint, embeddingEndpoint],
        credentials: [credential]
    )
}

private func ttsProfile() throws -> AIProviderConfigurationProfile {
    let now = Date(timeIntervalSince1970: 100)
    let text = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-1",
            profileID: "profile-1",
            purpose: .textGeneration,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-5.2",
            credentialID: "credential-1",
            supportsImageInput: true,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
    let tts = try AIProviderEndpointConfiguration(
        input: AIProviderEndpointInput(
            id: "endpoint-tts",
            profileID: "profile-1",
            purpose: .tts,
            isEnabled: true,
            providerPresetID: "openai",
            adapterKind: .openAIResponses,
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-4o-mini-tts",
            credentialID: "credential-1",
            supportsImageInput: false,
            imageInputEnabled: false
        ),
        createdAt: now,
        updatedAt: now
    )
    let credential = AIProviderCredentialMetadata(
        id: "credential-1",
        profileID: "profile-1",
        providerPresetID: "openai",
        kind: .apiKey,
        label: "OpenAI API Key",
        secretPresence: .present,
        createdAt: now,
        updatedAt: now
    )
    return AIProviderConfigurationProfile(
        id: "profile-1",
        displayName: "Default AI Provider",
        isDefault: true,
        status: .configured,
        createdAt: now,
        updatedAt: now,
        endpoints: [text, tts],
        credentials: [credential]
    )
}
