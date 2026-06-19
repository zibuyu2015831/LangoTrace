import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("TTS provider settings repository")
struct TTSProviderSettingsRepositoryTests {
    @Test("Migration creates endpoint settings and language voice profile tables")
    func migrationCreatesTTSProviderTables() async throws {
        let database = try AppDatabase.inMemory()

        let tables = try await database.databaseQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
                .map { $0["name"] as String }
        }

        #expect(tables.contains("ai_provider_tts_settings"))
        #expect(tables.contains("ai_provider_tts_voice_profiles"))
    }

    @Test("Repository saves endpoint settings and language scoped voice profiles")
    func repositorySavesEndpointSettingsAndLanguageScopedVoiceProfiles() async throws {
        let database = try AppDatabase.inMemory()
        let aiRepository = GRDBAIProviderConfigurationRepository(database: database)
        let ttsRepository = GRDBTTSProviderSettingsRepository(database: database)
        try await aiRepository.saveProfile(profileWithTTSEndpoint())

        let english = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "coral",
            outputFormat: .mp3
        )
        let japanese = try TTSVoiceProfile.make(
            id: "voice-ja",
            endpointID: "endpoint-tts",
            languageCode: "ja",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "alloy",
            outputFormat: .mp3
        )

        try await ttsRepository.saveSettings(
            TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
            voiceProfiles: [english, japanese]
        )

        #expect(try await ttsRepository.loadSettings(endpointID: "endpoint-tts")?.adapterKind == .openAIAudioSpeech)
        #expect(try await ttsRepository.loadVoiceProfile(endpointID: "endpoint-tts", languageCode: "en")?.voiceID == "coral")
        #expect(try await ttsRepository.loadVoiceProfile(endpointID: "endpoint-tts", languageCode: "ja")?.voiceID == "alloy")
    }

    @Test("TTS probe outcome updates voice profile without changing text profile summary")
    func ttsProbeOutcomeUpdatesVoiceProfileWithoutChangingTextProfileSummary() async throws {
        let database = try AppDatabase.inMemory()
        let aiRepository = GRDBAIProviderConfigurationRepository(database: database)
        let ttsRepository = GRDBTTSProviderSettingsRepository(database: database)
        try await aiRepository.saveProfile(profileWithTTSEndpoint())
        let voice = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "coral",
            outputFormat: .mp3
        )
        try await ttsRepository.saveSettings(
            TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
            voiceProfiles: [voice]
        )

        let event = AIProviderValidationEvent(
            id: "event-tts-1",
            profileID: "profile-1",
            endpointID: "endpoint-tts",
            eventType: .syntheticTest,
            status: .succeeded,
            errorCategory: nil,
            providerPresetID: "openai",
            modelName: "tts-1",
            durationMilliseconds: 210,
            createdAt: Date(timeIntervalSince1970: 300)
        )
        try await ttsRepository.recordTTSVoiceProfileProbeOutcome(event, languageCode: "en")

        let updatedVoice = try await ttsRepository.loadVoiceProfile(endpointID: "endpoint-tts", languageCode: "en")
        #expect(updatedVoice?.lastTestStatus == .succeeded)
        #expect(updatedVoice?.lastSuccessfulConfigurationFingerprint == voice.configurationFingerprint)

        let loadedProfile = try await aiRepository.loadDefaultProfile()
        #expect(loadedProfile?.lastValidatedAt == nil)
        #expect(loadedProfile?.lastValidationStatus == nil)
    }

    @Test("TTS probe outcome stores last failed error category on voice profile")
    func ttsProbeOutcomeStoresLastFailedErrorCategoryOnVoiceProfile() async throws {
        let database = try AppDatabase.inMemory()
        let aiRepository = GRDBAIProviderConfigurationRepository(database: database)
        let ttsRepository = GRDBTTSProviderSettingsRepository(database: database)
        try await aiRepository.saveProfile(profileWithTTSEndpoint())
        let voice = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "coral",
            outputFormat: .mp3
        )
        try await ttsRepository.saveSettings(
            TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
            voiceProfiles: [voice]
        )

        let event = AIProviderValidationEvent(
            id: "event-tts-failed",
            profileID: "profile-1",
            endpointID: "endpoint-tts",
            eventType: .syntheticTest,
            status: .failed,
            errorCategory: .invalidVoice,
            providerPresetID: "openai",
            modelName: "tts-1",
            durationMilliseconds: 210,
            createdAt: Date(timeIntervalSince1970: 320)
        )
        try await ttsRepository.recordTTSVoiceProfileProbeOutcome(event, languageCode: "en")

        let updatedVoice = try await ttsRepository.loadVoiceProfile(endpointID: "endpoint-tts", languageCode: "en")
        #expect(updatedVoice?.lastTestStatus == .failed)
        #expect(updatedVoice?.lastTestErrorCategory == .invalidVoice)
    }

    @Test("TTS probe outcome without endpoint id throws instead of silently updating nothing")
    func ttsProbeOutcomeWithoutEndpointIDThrows() async throws {
        let database = try AppDatabase.inMemory()
        let aiRepository = GRDBAIProviderConfigurationRepository(database: database)
        let ttsRepository = GRDBTTSProviderSettingsRepository(database: database)
        try await aiRepository.saveProfile(profileWithTTSEndpoint())
        let voice = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "coral",
            outputFormat: .mp3
        )
        try await ttsRepository.saveSettings(
            TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
            voiceProfiles: [voice]
        )

        let event = AIProviderValidationEvent(
            id: "event-tts-missing-endpoint",
            profileID: "profile-1",
            endpointID: nil,
            eventType: .syntheticTest,
            status: .succeeded,
            errorCategory: nil,
            providerPresetID: "openai",
            modelName: "tts-1",
            durationMilliseconds: 210,
            createdAt: Date(timeIntervalSince1970: 300)
        )

        await #expect(throws: TTSProviderSettingsRepositoryError.missingEndpointID) {
            try await ttsRepository.recordTTSVoiceProfileProbeOutcome(event, languageCode: "en")
        }

        let untouchedVoice = try await ttsRepository.loadVoiceProfile(endpointID: "endpoint-tts", languageCode: "en")
        #expect(untouchedVoice?.lastTestStatus == .notTested)
        #expect(untouchedVoice?.lastTestedAt == nil)
    }

    private func profileWithTTSEndpoint() throws -> AIProviderConfigurationProfile {
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
        let ttsEndpoint = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "endpoint-tts",
                profileID: "profile-1",
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "tts-1",
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
            endpoints: [textEndpoint, ttsEndpoint],
            credentials: [credential]
        )
    }
}
