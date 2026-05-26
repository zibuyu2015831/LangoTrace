import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceUI

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
        let availabilityService = AIProviderConfigurationService(
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

actor SentenceAudioPlaybackCoordinatorBox {
    private let makeCoordinator: @Sendable () throws -> SentenceAudioPlaybackCoordinator
    private var coordinator: SentenceAudioPlaybackCoordinator?

    init(makeCoordinator: @escaping @Sendable () throws -> SentenceAudioPlaybackCoordinator) {
        self.makeCoordinator = makeCoordinator
    }

    nonisolated func actions() -> SentenceAudioPlaybackActions {
        SentenceAudioPlaybackActions(
            handleTap: { request in
                do {
                    let coordinator = try await self.coordinatorInstance()
                    try await coordinator.handleTap(request)
                    return await coordinator.presentationState(for: request)
                } catch let failure as SentenceAudioPlaybackFailure {
                    return .failed(failure)
                } catch {
                    return .failed(.playbackFailed)
                }
            },
            presentationState: { request in
                do {
                    let coordinator = try await self.coordinatorInstance()
                    return await coordinator.presentationState(for: request)
                } catch {
                    return .failed(.playbackFailed)
                }
            },
            stateUpdates: { request in
                do {
                    let coordinator = try await self.coordinatorInstance()
                    return await coordinator.stateUpdates(for: request)
                } catch {
                    return AsyncStream { continuation in
                        continuation.yield(.failed(.playbackFailed))
                        continuation.finish()
                    }
                }
            },
            stopActivePlayback: {
                do {
                    let coordinator = try await self.coordinatorInstance()
                    await coordinator.stopActivePlayback()
                } catch {}
            }
        )
    }

    private func coordinatorInstance() throws -> SentenceAudioPlaybackCoordinator {
        if let coordinator {
            return coordinator
        }
        let newCoordinator = try makeCoordinator()
        coordinator = newCoordinator
        return newCoordinator
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
