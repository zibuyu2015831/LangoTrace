import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceUI

/// Assembles the photo-writing action seams: local photo import (never sent to
/// AI) plus the two explicitly-triggered assist seams.
///
/// `sanitizeImage` is the single boundary that downsamples + strips EXIF/GPS via
/// `AIImageSanitizer` — the only way raw picker bytes become sendable (privacy
/// floor P1-1 / P1-2). `requestAssist` resolves the default text endpoint +
/// credential, sends the sanitized image with the language-space input the view
/// already supplied, writes a non-sensitive request log, and maps failures onto
/// `PhotoWritingAssistRequestFailure`. Never auto-runs — only the explicit
/// "ask AI about this photo" action reaches here (core decision 10).
enum PhotoWritingActionsAssembly {
    static func makeActions(
        database: AppDatabase,
        fileStore: LocalMediaArtifactFileStore,
        credentialStore: (any AIProviderCredentialStore)?,
        aiRequestLogRecorder: AIRequestLogRecorder
    ) -> PhotoWritingActions {
        let pipeline = PhotoImportPipeline(fileStore: fileStore, database: database)
        return PhotoWritingActions(
            importPhoto: { data, entryID, spaceID in
                _ = try pipeline.importPhoto(data: data, entryID: entryID, spaceID: spaceID)
            },
            sanitizeImage: { data in
                do {
                    return try AIImageSanitizer.sanitizeForAI(data)
                } catch {
                    // Couldn't prepare a sendable image (undecodable or cannot fit
                    // the byte budget); surface as a non-guidance failure.
                    throw PhotoWritingAssistRequestFailure(category: .imageTooLarge)
                }
            },
            requestAssist: makeRequestAssist(
                database: database,
                credentialStore: credentialStore,
                aiRequestLogRecorder: aiRequestLogRecorder
            )
        )
    }

    private static func makeRequestAssist(
        database: AppDatabase,
        credentialStore: (any AIProviderCredentialStore)?,
        aiRequestLogRecorder: AIRequestLogRecorder
    ) -> @Sendable (PhotoWritingAssistInput, SanitizedAIImage) async throws -> PhotoWritingAssistResult {
        { input, image in
            guard let credentialStore else {
                throw PhotoWritingAssistRequestFailure(category: .providerNotConfigured)
            }
            let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
            guard let profile = try await configurationRepository.loadDefaultProfile(),
                  let endpoint = profile.textGenerationEndpointInput
            else {
                throw PhotoWritingAssistRequestFailure(category: .providerNotConfigured)
            }
            let secret: String?
            do {
                secret = try await resolveLearningMaterialSecret(
                    endpoint: endpoint,
                    profile: profile,
                    credentialStore: credentialStore
                )
            } catch {
                throw PhotoWritingAssistRequestFailure(category: .providerNotConfigured)
            }
            let request = PhotoWritingAssistServiceRequest(
                endpoint: endpoint,
                plaintextSecret: secret,
                input: input,
                image: image
            )
            let service = PhotoWritingAssistService(httpClient: URLSessionAIProviderHTTPClient())
            let logID = UUID().uuidString
            do {
                let result = try await service.assist(request)
                await aiRequestLogRecorder.record(request.makeLogEntry(id: logID, outcome: .success, createdAt: Date()))
                return result
            } catch let error as PhotoWritingAssistServiceError {
                let outcome: AIRequestLogOutcome = error.category == .cancelled
                    ? .cancelled
                    : .failed(AIRequestLogFailureBucket(error.category))
                await aiRequestLogRecorder.record(request.makeLogEntry(id: logID, outcome: outcome, createdAt: Date()))
                throw PhotoWritingAssistRequestFailure(category: error.category)
            } catch is CancellationError {
                await aiRequestLogRecorder.record(request.makeLogEntry(id: logID, outcome: .cancelled, createdAt: Date()))
                throw PhotoWritingAssistRequestFailure(category: .cancelled)
            }
        }
    }
}
