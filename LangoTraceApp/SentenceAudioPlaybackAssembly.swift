import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech

enum SentenceAudioPlaybackAssembly {
    static func makeCoordinator(
        database: AppDatabase,
        mediaArtifactsRoot: URL,
        credentialStore: any AIProviderCredentialStore,
        diagnosticLogger: any DiagnosticLogging,
        ttsPreviewStore: any TTSAudioPreviewStore
    ) throws -> SentenceAudioPlaybackCoordinator {
        let fileStore = try LocalMediaArtifactFileStore(rootDirectory: mediaArtifactsRoot)
        let mediaStore = LocalMediaArtifactStore(
            repository: GRDBMediaArtifactRepository(database: database),
            fileStore: fileStore,
            audioFileValidator: TTSAudioFileValidator(mediaArtifactsRoot: mediaArtifactsRoot)
        )
        let availabilityService = try AIProviderConfigurationService(
            repository: GRDBAIProviderConfigurationRepository(database: database),
            credentialStore: credentialStore,
            configurationProbeService: AIProviderConfigurationProbeService(
                httpClient: URLSessionAIProviderProbeHTTPClient(),
                diagnosticLogger: diagnosticLogger
            ),
            ttsConfigurationProbeService: TTSConfigurationProbeService(
                httpClient: URLSessionAIProviderProbeHTTPClient(),
                audioValidationService: DefaultTTSAudioValidationService(previewStore: ttsPreviewStore)
            ),
            diagnosticLogger: diagnosticLogger
        )
        return SentenceAudioPlaybackCoordinator(
            availabilityService: availabilityService,
            secretResolver: AppPlayableTTSSecretResolver(
                repository: GRDBAIProviderConfigurationRepository(database: database),
                credentialStore: credentialStore
            ),
            mediaStore: mediaStore,
            generationService: SentenceTTSGenerationService(
                httpClient: URLSessionAIProviderHTTPClient(),
                responseValidator: TTSAudioResponseValidator(
                    audioValidationService: DefaultTTSAudioValidationService()
                ),
                stagingWriter: fileStore
            ),
            playbackSourceResolver: LocalMediaArtifactPlaybackSourceResolver(fileStore: fileStore),
            player: TTSAudioPlaybackService()
        )
    }

    static func defaultMediaArtifactsRoot() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport
            .appendingPathComponent("LangoTrace", isDirectory: true)
            .appendingPathComponent("MediaArtifacts", isDirectory: true)
    }
}

private struct AppPlayableTTSSecretResolver: PlayableTTSSecretResolving {
    private let repository: any AIProviderConfigurationRepository
    private let credentialStore: any AIProviderCredentialStore

    init(
        repository: any AIProviderConfigurationRepository,
        credentialStore: any AIProviderCredentialStore
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
    }

    func plaintextSecret(for configuration: PlayableTTSConfiguration) async throws -> String? {
        guard let credentialID = configuration.endpoint.credentialID,
              let profile = try await repository.loadDefaultProfile(),
              let credential = profile.credentials.first(where: { $0.id == credentialID })
        else {
            return nil
        }
        return try await credentialStore
            .resolveSecret(for: AIProviderCredentialKeychainReference(metadata: credential))
            .value
    }
}
