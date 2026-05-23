import Foundation
import GRDB
import LangoTraceCore

public struct GRDBTTSProviderSettingsRepository: @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(database: AppDatabase) {
        databaseQueue = database.databaseQueue
    }

    init(databaseQueue: DatabaseQueue) {
        self.databaseQueue = databaseQueue
    }

    public func saveSettings(
        _ settings: TTSProviderSettings,
        voiceProfiles: [TTSVoiceProfile]
    ) async throws {
        try await databaseQueue.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(
                sql: """
                INSERT INTO ai_provider_tts_settings (
                    endpoint_id, tts_adapter_kind, created_at, updated_at
                ) VALUES (?, ?, ?, ?)
                ON CONFLICT(endpoint_id) DO UPDATE SET
                    tts_adapter_kind = excluded.tts_adapter_kind,
                    updated_at = excluded.updated_at
                """,
                arguments: [settings.endpointID, settings.adapterKind.rawValue, now, now]
            )

            for profile in voiceProfiles {
                try upsert(profile, now: now, db: db)
            }
        }
    }

    public func loadSettings(endpointID: AIProviderEndpointID) async throws -> TTSProviderSettings? {
        try await databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM ai_provider_tts_settings WHERE endpoint_id = ?",
                arguments: [endpointID]
            ) else {
                return nil
            }
            return TTSProviderSettings(
                endpointID: row["endpoint_id"],
                adapterKind: TTSProviderAdapterKind(rawValue: row["tts_adapter_kind"] as String) ?? .openAIAudioSpeech
            )
        }
    }

    public func loadVoiceProfile(
        endpointID: AIProviderEndpointID,
        languageCode: String
    ) async throws -> TTSVoiceProfile? {
        try await databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT *
                FROM ai_provider_tts_voice_profiles
                WHERE endpoint_id = ? AND language_code = ?
                """,
                arguments: [endpointID, languageCode]
            ) else {
                return nil
            }
            return try voiceProfile(from: row)
        }
    }

    public func recordTTSVoiceProfileProbeOutcome(
        _ event: AIProviderValidationEvent,
        languageCode: String
    ) async throws {
        try await databaseQueue.write { db in
            try insert(event, db: db)
            let endpointID = event.endpointID ?? ""
            let testedAt = event.createdAt.timeIntervalSince1970
            let currentFingerprint: String? = try String.fetchOne(
                db,
                sql: """
                SELECT configuration_fingerprint
                FROM ai_provider_tts_voice_profiles
                WHERE endpoint_id = ? AND language_code = ?
                """,
                arguments: [endpointID, languageCode]
            )
            let successfulFingerprint = event.status == .succeeded ? currentFingerprint : nil
            try db.execute(
                sql: """
                UPDATE ai_provider_tts_voice_profiles
                SET last_test_status = ?,
                    last_test_error_category = ?,
                    last_tested_at = ?,
                    last_successful_configuration_fingerprint = COALESCE(?, last_successful_configuration_fingerprint),
                    updated_at = ?
                WHERE endpoint_id = ? AND language_code = ?
                """,
                arguments: [
                    event.status.ttsStatus.rawValue,
                    event.status == .succeeded ? nil : event.errorCategory?.rawValue,
                    testedAt,
                    successfulFingerprint,
                    testedAt,
                    endpointID,
                    languageCode,
                ]
            )
        }
    }
}

private extension GRDBTTSProviderSettingsRepository {
    func upsert(_ profile: TTSVoiceProfile, now: Double, db: Database) throws {
        let providerParametersData = try encoder.encode(profile.providerParameters)
        let providerParametersJSON = String(data: providerParametersData, encoding: .utf8) ?? "{}"
        try db.execute(
            sql: """
            INSERT INTO ai_provider_tts_voice_profiles (
                id, endpoint_id, language_code, tts_adapter_kind, model_name,
                voice_id, voice_display_name, output_format, sample_rate,
                speed, volume, pitch, style_prompt, instructions, streaming_mode,
                provider_parameters_json, configuration_fingerprint,
                last_successful_configuration_fingerprint, last_test_status,
                last_test_error_category, last_tested_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(endpoint_id, language_code) DO UPDATE SET
                id = excluded.id,
                tts_adapter_kind = excluded.tts_adapter_kind,
                model_name = excluded.model_name,
                voice_id = excluded.voice_id,
                voice_display_name = excluded.voice_display_name,
                output_format = excluded.output_format,
                sample_rate = excluded.sample_rate,
                speed = excluded.speed,
                volume = excluded.volume,
                pitch = excluded.pitch,
                style_prompt = excluded.style_prompt,
                instructions = excluded.instructions,
                streaming_mode = excluded.streaming_mode,
                provider_parameters_json = excluded.provider_parameters_json,
                configuration_fingerprint = excluded.configuration_fingerprint,
                last_successful_configuration_fingerprint = excluded.last_successful_configuration_fingerprint,
                last_test_status = excluded.last_test_status,
                last_test_error_category = excluded.last_test_error_category,
                last_tested_at = excluded.last_tested_at,
                updated_at = excluded.updated_at
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
                providerParametersJSON,
                profile.configurationFingerprint,
                profile.lastSuccessfulConfigurationFingerprint,
                profile.lastTestStatus.rawValue,
                profile.lastTestErrorCategory?.rawValue,
                profile.lastTestedAt?.timeIntervalSince1970,
                now,
                now,
            ]
        )
    }

    func voiceProfile(from row: Row) throws -> TTSVoiceProfile {
        let providerParametersJSON: String = row["provider_parameters_json"]
        let providerParametersData = Data(providerParametersJSON.utf8)
        let providerParameters = try decoder.decode(
            [String: TTSProviderParameterValue].self,
            from: providerParametersData
        )
        return try TTSVoiceProfile.make(
            id: row["id"],
            endpointID: row["endpoint_id"],
            languageCode: row["language_code"],
            adapterKind: TTSProviderAdapterKind(rawValue: row["tts_adapter_kind"] as String) ?? .openAIAudioSpeech,
            modelName: row["model_name"],
            voiceID: row["voice_id"],
            voiceDisplayName: row["voice_display_name"],
            outputFormat: TTSAudioFormat(rawValue: row["output_format"] as String) ?? .mp3,
            sampleRate: row["sample_rate"],
            speed: row["speed"],
            volume: row["volume"],
            pitch: row["pitch"],
            stylePrompt: row["style_prompt"],
            instructions: row["instructions"],
            streamingMode: row["streaming_mode"],
            providerParameters: providerParameters,
            lastSuccessfulConfigurationFingerprint: row["last_successful_configuration_fingerprint"],
            lastTestStatus: TTSConfigurationStatus(rawValue: row["last_test_status"] as String) ?? .notTested,
            lastTestErrorCategory: (row["last_test_error_category"] as String?)
                .flatMap(AIProviderValidationErrorCategory.init(rawValue:)),
            lastTestedAt: (row["last_tested_at"] as Double?).map(Date.init(timeIntervalSince1970:))
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
}

private extension AIProviderValidationStatus {
    var ttsStatus: TTSConfigurationStatus {
        switch self {
        case .notRun:
            .notTested
        case .succeeded:
            .succeeded
        case .failed:
            .failed
        case .cancelled:
            .notTested
        }
    }
}
