import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import LangoTraceUI
import os
import SwiftUI

private let generationLogger = Logger(subsystem: "com.zibuyu.LangoTrace", category: "generation")

struct AppEnvironment {
    let makeLanguageSpaceRepository: @Sendable () throws -> any LanguageSpaceRepository
    let learningContentRepository: any LearningContentRepository
    let learningMaterialGenerationActions: LearningMaterialGenerationActions
    let sentenceAudioPlaybackActions: SentenceAudioPlaybackActions
    let readingLibraryActions: ReadingLibraryActions
    let readingExplanationAction: ReadingExplanationAction
    let readingTTSAction: ReadingTTSAction
    let readingCacheStorage: (any ReadingExplanationCacheRepositoryProtocol)?
    let practiceActions: PracticeActions
    let photoWritingActions: PhotoWritingActions
    let aiProviderSettingsActions: AIProviderSettingsActions
    let syncService: any SyncService

    // AppEnvironment assembles the cross-package production graph in one place.
    // swiftlint:disable:next function_body_length
    static func bootstrap(databaseURL: URL? = nil) -> AppEnvironment {
        let databaseFactory = SharedAppDatabaseFactory(databaseURL: databaseURL)
        let credentialStore = KeychainAIProviderCredentialStore()
        let diagnosticLogger = makeDiagnosticLogger(databaseFactory: databaseFactory)
        let learningContentRepository = makeLearningContentRepository(
            databaseFactory: databaseFactory,
            diagnosticLogger: diagnosticLogger
        )
        let ttsPreviewStore = InMemoryTTSAudioPreviewStore()
        let ttsPreviewPlaybackService = DefaultTTSAudioPreviewPlaybackService(previewStore: ttsPreviewStore)
        let sentenceAudioPlaybackCoordinatorBox = SentenceAudioPlaybackCoordinatorBox {
            try SentenceAudioPlaybackAssembly.makeCoordinator(
                database: databaseFactory.database(),
                mediaArtifactsRoot: SentenceAudioPlaybackAssembly.defaultMediaArtifactsRoot(),
                credentialStore: credentialStore,
                diagnosticLogger: diagnosticLogger,
                ttsPreviewStore: ttsPreviewStore
            )
        }

        let readingCacheStorage: (any ReadingExplanationCacheRepositoryProtocol)?
        do {
            readingCacheStorage = try GRDBReadingExplanationCacheRepository(
                database: databaseFactory.database()
            )
        } catch {
            readingCacheStorage = nil
            recordBootstrapComponentFailure(
                component: "reading_explanation_cache",
                error: error,
                name: .aiProviderConfigurationDatabaseWriteFailed,
                domain: .dataStorage,
                diagnosticLogger: diagnosticLogger
            )
        }

        let practiceActions: PracticeActions
        do {
            practiceActions = try PracticeActionsAssembly.makeActions(
                database: databaseFactory.database(),
                mediaArtifactsRoot: SentenceAudioPlaybackAssembly.defaultMediaArtifactsRoot(),
                diagnosticLogger: diagnosticLogger
            )
        } catch {
            practiceActions = .disabled
            recordBootstrapComponentFailure(
                component: "practice_actions",
                error: error,
                name: .practiceRecordingFailed,
                domain: .practiceRecording,
                diagnosticLogger: diagnosticLogger
            )
        }

        let photoWritingActions: PhotoWritingActions
        do {
            let database = try databaseFactory.database()
            let mediaRoot = try SentenceAudioPlaybackAssembly.defaultMediaArtifactsRoot()
            let fileStore = try LocalMediaArtifactFileStore(rootDirectory: mediaRoot)
            let pipeline = PhotoImportPipeline(fileStore: fileStore, database: database)
            photoWritingActions = PhotoWritingActions { data, entryID, spaceID in
                _ = try pipeline.importPhoto(data: data, entryID: entryID, spaceID: spaceID)
            }
        } catch {
            photoWritingActions = .disabled
            recordBootstrapComponentFailure(
                component: "photo_writing_actions",
                error: error,
                name: .aiProviderConfigurationDatabaseWriteFailed,
                domain: .dataStorage,
                diagnosticLogger: diagnosticLogger
            )
        }

        return AppEnvironment(
            makeLanguageSpaceRepository: {
                try GRDBLanguageSpaceRepository(
                    database: databaseFactory.database()
                )
            },
            learningContentRepository: learningContentRepository,
            learningMaterialGenerationActions: makeLearningMaterialGenerationActions(
                databaseFactory: databaseFactory,
                credentialStore: credentialStore
            ),
            sentenceAudioPlaybackActions: sentenceAudioPlaybackCoordinatorBox.actions(),
            readingLibraryActions: makeReadingLibraryActions(databaseFactory: databaseFactory),
            readingExplanationAction: makeReadingExplanationAction(
                databaseFactory: databaseFactory,
                credentialStore: credentialStore
            ),
            readingTTSAction: makeReadingTTSAction(
                sentenceAudioPlaybackActions: sentenceAudioPlaybackCoordinatorBox.actions()
            ),
            readingCacheStorage: readingCacheStorage,
            practiceActions: practiceActions,
            photoWritingActions: photoWritingActions,
            aiProviderSettingsActions: AIProviderSettingsActions(
                loadDefaultProfile: {
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger,
                        ttsPreviewStore: ttsPreviewStore
                    )
                    return try await service.loadDefaultProfile()
                },
                loadTTSVoiceProfile: { endpointID, languageCode in
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger,
                        ttsPreviewStore: ttsPreviewStore
                    )
                    return try await service.loadTTSVoiceProfile(endpointID: endpointID, languageCode: languageCode)
                },
                resolveCredentialSecret: { credential in
                    do {
                        let secret = try await credentialStore.resolveSecret(
                            for: AIProviderCredentialKeychainReference(metadata: credential)
                        )
                        return secret.value
                    } catch let error as AIProviderCredentialStoreError {
                        throw AIProviderCredentialResolveFailure(
                            category: credentialResolveFailureCategory(for: error)
                        )
                    }
                },
                saveDefaultProfile: { input, operationID in
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger,
                        ttsPreviewStore: ttsPreviewStore
                    )
                    return try await service.saveDefaultProfile(input, operationID: operationID)
                },
                validateDefaultProfileCredentials: {
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger,
                        ttsPreviewStore: ttsPreviewStore
                    )
                    return try await service.validateDefaultProfileCredentials()
                },
                testProviderConfiguration: { source, snapshot, languageContext, operationID in
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger,
                        ttsPreviewStore: ttsPreviewStore
                    )
                    switch source {
                    case .draft:
                        guard let snapshot else {
                            throw AIProviderConfigurationError.missingRequiredEndpointField
                        }
                        return try await service.testDraftConfiguration(
                            AIProviderConfigurationProbeDraftInput(
                                endpoint: snapshot.endpoint,
                                plaintextSecret: snapshot.plaintextSecret,
                                ttsEndpoint: snapshot.ttsEndpoint,
                                ttsSettings: snapshot.ttsSettings,
                                ttsVoiceProfile: snapshot.ttsVoiceProfile,
                                ttsPlaintextSecret: snapshot.ttsPlaintextSecret,
                                embeddingEndpoint: snapshot.embeddingEndpoint,
                                embeddingPlaintextSecret: snapshot.embeddingPlaintextSecret,
                                languageContext: snapshot.languageContext,
                                operationID: operationID
                            )
                        )
                    case .savedProfile:
                        return try await service.testDefaultConfiguration(
                            languageContext: languageContext,
                            operationID: operationID
                        )
                    }
                },
                playSpeechPreview: { resource in
                    try? await ttsPreviewPlaybackService.playPreview(resource)
                },
                recordDiagnosticEvent: { event in
                    await diagnosticLogger.record(event)
                }
            ),
            syncService: DisabledSyncService()
        )
    }
}

private func makeReadingExplanationAction(
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore
) -> ReadingExplanationAction {
    { request in
        let database = try databaseFactory.database()
        let readingRepository = GRDBReadingLibraryRepository(database: database)
        let promptID = ReadingSelectionExplanationPromptRegistry.promptID
        let promptVersion = ReadingSelectionExplanationPromptRegistry.promptVersion
        let configurationRepository = GRDBAIProviderConfigurationRepository(
            database: database
        )
        var baseRecord = ReadingAIExplanationOperationRecord()
        baseRecord.documentID = request.documentID
        baseRecord.spaceID = request.spaceID
        baseRecord.promptID = promptID
        baseRecord.promptVersion = promptVersion
        baseRecord.selectedText = request.selectedText
        baseRecord.sentenceText = request.containingSentence.isEmpty ? nil : request.containingSentence
        baseRecord.contextCharacterCount = request.contextText.count
        let recorder = ReadingExplanationOperationRecorder(
            repository: readingRepository,
            base: baseRecord
        )
        guard let profile = try await configurationRepository.loadDefaultProfile(),
              let endpoint = profile.textGenerationEndpointInput
        else {
            recorder.record(.failed(category: "providerNotConfigured"))
            throw ReadingSelectionExplanationServiceError(category: .providerNotConfigured)
        }
        recorder.record(.pending, profile: profile, endpoint: endpoint)
        let plaintextSecret = try await resolveLearningMaterialSecret(
            endpoint: endpoint,
            profile: profile,
            credentialStore: credentialStore
        )
        let service = ReadingSelectionExplanationService(httpClient: URLSessionAIProviderHTTPClient())
        do {
            let result = try await service.explain(
                ReadingSelectionExplanationServiceRequest(
                    endpoint: endpoint,
                    plaintextSecret: plaintextSecret,
                    input: ReadingSelectionExplanationInput(
                        documentID: request.documentID,
                        sourceAnchorID: request.sourceAnchorID,
                        selectedText: request.selectedText,
                        selectionScope: request.selectionScope,
                        containingSentence: request.containingSentence,
                        previousSentence: request.previousSentence,
                        nextSentence: request.nextSentence,
                        containingParagraph: request.containingParagraph,
                        contextMode: request.contextMode,
                        contextText: request.contextText,
                        nativeLanguageCode: request.nativeLanguageCode,
                        targetLanguageCode: request.targetLanguageCode,
                        proficiencyLevelCode: request.proficiencyLevelCode,
                        explanationLanguageMode: request.explanationLanguageMode
                    )
                )
            )
            recorder.record(.succeeded, profile: profile, endpoint: endpoint)
            return result
        } catch let error as CancellationError {
            recorder.record(.cancelled, profile: profile, endpoint: endpoint)
            throw error
        } catch let error as ReadingSelectionExplanationServiceError {
            recorder.record(.failed(category: "\(error.category)"), profile: profile, endpoint: endpoint)
            throw error
        } catch {
            recorder.record(.failed(category: "providerRejected"), profile: profile, endpoint: endpoint)
            throw error
        }
    }
}

private func makeReadingTTSAction(
    sentenceAudioPlaybackActions: SentenceAudioPlaybackActions
) -> ReadingTTSAction {
    { request in
        let audioRequest = SentenceAudioRequest(
            languageSpaceID: request.spaceID,
            owner: .readingDocumentSentence(
                documentID: request.documentID,
                sentenceID: request.sentenceID
            ),
            sentenceSource: .readingDocumentSentence(
                documentID: request.documentID,
                sentenceID: request.sentenceID
            ),
            sentenceIndex: request.sentenceIndex,
            targetText: request.text,
            targetLanguageCode: request.targetLanguageCode
        )
        let state = await sentenceAudioPlaybackActions.handleTap(audioRequest)
        switch state {
        case .idle, .playing, .generating, .paused:
            return .success
        case let .failed(failure):
            return .failed(failure.rawValue)
        case let .requiresConfiguration(issue):
            return .failed(issue.rawValue)
        }
    }
}

private func makeReadingLibraryActions(
    databaseFactory: SharedAppDatabaseFactory
) -> ReadingLibraryActions {
    ReadingLibraryActions(
        listDocuments: { spaceID, includeDeleted, query in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            return try repository.listDocuments(
                spaceID: spaceID,
                includeDeleted: includeDeleted,
                search: query
            )
        },
        importPastedText: { input in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            return try repository.importInlineDocument(input)
        },
        loadDocument: { id, spaceID in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            return try repository.documentContent(id: id, spaceID: spaceID)
        },
        updateDocument: { input in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            return try repository.updateDocument(input)
        },
        softDeleteDocument: { id, spaceID in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            try repository.softDeleteDocument(id: id, spaceID: spaceID)
        },
        restoreDocument: { id, spaceID in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            try repository.restoreDocument(id: id, spaceID: spaceID)
        },
        markDocumentOpened: { id, spaceID in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            try repository.markDocumentOpened(id: id, spaceID: spaceID)
        },
        assignCollection: { id, spaceID, title in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            try repository.assignCollection(documentID: id, spaceID: spaceID, title: title)
        },
        tagDocument: { id, spaceID, name in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            try repository.tagDocument(documentID: id, spaceID: spaceID, name: name)
        }
    )
}

private func makeLearningContentRepository(
    databaseFactory: SharedAppDatabaseFactory,
    diagnosticLogger: any DiagnosticLogging
) -> any LearningContentRepository {
    do {
        return try GRDBLearningContentRepositoryBridge(
            repository: GRDBLearningContentRepository(database: databaseFactory.database())
        )
    } catch {
        recordBootstrapComponentFailure(
            component: "learning_content_repository",
            error: error,
            name: .aiProviderConfigurationDatabaseWriteFailed,
            domain: .dataStorage,
            diagnosticLogger: diagnosticLogger
        )
        return UnavailableLearningContentRepository()
    }
}

/// Bootstrap fallbacks must not fail silently. There is no dedicated bootstrap event name in
/// `DiagnosticEventName` yet, so storage-related fallbacks reuse the closest database failure
/// name with `.dataStorage` domain and a `bootstrap_*` failure phase attribute.
private func recordBootstrapComponentFailure(
    component: String,
    error: Error,
    name: DiagnosticEventName,
    domain: DiagnosticDomain,
    diagnosticLogger: any DiagnosticLogging
) {
    let event = DiagnosticEvent(
        id: UUID().uuidString,
        name: name,
        domain: domain,
        level: .error,
        outcome: .failed,
        attributes: [
            .failurePhase("bootstrap_\(component)"),
            .errorCategory(String(describing: type(of: error))),
        ],
        createdAt: Date()
    )
    Task {
        await diagnosticLogger.record(event)
    }
}

// swiftlint:disable:next function_body_length
private func makeLearningMaterialGenerationActions(
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore
) -> LearningMaterialGenerationActions {
    LearningMaterialGenerationActions(
        generateMaterial: { input, operationID, bucket in
            do {
                let database = try databaseFactory.database()
                let learningRepository = GRDBLearningContentRepository(database: database)
                let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
                try learningRepository.recordOperation(
                    .started(
                        operationID: operationID,
                        entryID: input.entryID,
                        kind: .generate,
                        bucket: bucket,
                        createdAt: Date()
                    )
                )

                guard let profile = try await configurationRepository.loadDefaultProfile(),
                      let endpoint = profile.textGenerationEndpointInput
                else {
                    generationLogger.error("generate failed: providerNotConfigured — no default profile or no enabled textGeneration endpoint")
                    try recordLearningMaterialFailure(
                        .providerNotConfigured,
                        operationID: operationID,
                        entryID: input.entryID,
                        kind: .generate,
                        bucket: bucket,
                        repository: learningRepository
                    )
                    return .failed(.providerNotConfigured)
                }

                let plaintextSecret = try await resolveLearningMaterialSecret(
                    endpoint: endpoint,
                    profile: profile,
                    credentialStore: credentialStore
                )
                let service = LearningMaterialGenerationService(
                    httpClient: URLSessionAIProviderProbeHTTPClient()
                )
                let result = try await service.generate(
                    LearningMaterialServiceGenerationRequest(
                        endpoint: endpoint,
                        plaintextSecret: plaintextSecret,
                        input: input,
                        operationID: operationID,
                        lengthBucket: bucket
                    )
                )
                let material = try learningRepository.saveGeneratedMaterial(
                    result,
                    for: input.entryID,
                    operationSummary: LearningMaterialOperationSummary(
                        operationID: operationID,
                        entryID: input.entryID,
                        materialID: nil,
                        kind: .generate,
                        status: .succeeded,
                        failureCategory: nil,
                        promptID: result.metadata.promptID,
                        promptVersion: result.metadata.promptVersion,
                        providerProfileID: result.metadata.providerProfileID,
                        providerEndpointID: result.metadata.providerEndpointID,
                        providerPresetID: result.metadata.providerPresetID,
                        modelName: result.metadata.modelName,
                        inputKind: result.inputKind,
                        estimatedTokenBucket: bucket,
                        durationMilliseconds: nil,
                        createdAt: result.metadata.generatedAt,
                        completedAt: Date()
                    )
                )
                return .generated(material)
            } catch let error as LearningMaterialGenerationServiceError {
                generationLogger.error("generate failed: \(error.category.rawValue, privacy: .public)")
                try? recordLearningMaterialFailure(
                    error.category,
                    operationID: operationID,
                    entryID: input.entryID,
                    kind: .generate,
                    bucket: bucket,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(error.category)
            } catch let error as AIProviderCredentialStoreError {
                generationLogger.error("generate failed: credentialMissing — \(String(describing: error), privacy: .public)")
                let category: LearningMaterialGenerationFailureCategory = switch error {
                case .missingCredential, .credentialInaccessible, .credentialCorrupted, .userInteractionRequired:
                    .credentialMissing
                }
                try? recordLearningMaterialFailure(
                    category,
                    operationID: operationID,
                    entryID: input.entryID,
                    kind: .generate,
                    bucket: bucket,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(category)
            } catch {
                generationLogger.error("generate failed: unknown — \(String(describing: error), privacy: .public)")
                try? recordLearningMaterialFailure(
                    .unknown,
                    operationID: operationID,
                    entryID: input.entryID,
                    kind: .generate,
                    bucket: bucket,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(.unknown)
            }
        },
        updateLearningText: { materialID, learningText in
            do {
                let repository = try GRDBLearningContentRepository(database: databaseFactory.database())
                let material = try repository.updateLearningText(
                    materialID: materialID,
                    learningText: learningText
                )
                return .generated(material)
            } catch {
                return .failed(.persistenceFailed)
            }
        },
        analyzeCurrentText: { input, operationID, bucket in
            do {
                let database = try databaseFactory.database()
                let learningRepository = GRDBLearningContentRepository(database: database)
                let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
                guard let existingMaterial = try learningRepository.material(id: input.materialID) else {
                    return .failed(.persistenceFailed)
                }
                try learningRepository.recordOperation(
                    .started(
                        operationID: operationID,
                        entryID: existingMaterial.entryID,
                        kind: .analyze,
                        bucket: bucket,
                        createdAt: Date(),
                        promptID: LearningMaterialPromptRegistry.analysisPromptID
                    )
                )
                guard let profile = try await configurationRepository.loadDefaultProfile(),
                      let endpoint = profile.textGenerationEndpointInput
                else {
                    generationLogger.error("analyze failed: providerNotConfigured — no default profile or no enabled textGeneration endpoint")
                    try recordLearningMaterialFailure(
                        .providerNotConfigured,
                        operationID: operationID,
                        entryID: existingMaterial.entryID,
                        kind: .analyze,
                        bucket: bucket,
                        promptID: LearningMaterialPromptRegistry.analysisPromptID,
                        repository: learningRepository
                    )
                    return .failed(.providerNotConfigured)
                }
                let plaintextSecret = try await resolveLearningMaterialSecret(
                    endpoint: endpoint,
                    profile: profile,
                    credentialStore: credentialStore
                )
                let service = LearningMaterialGenerationService(
                    httpClient: URLSessionAIProviderProbeHTTPClient()
                )
                let result = try await service.analyze(
                    LearningMaterialServiceAnalysisRequest(
                        endpoint: endpoint,
                        plaintextSecret: plaintextSecret,
                        input: input,
                        operationID: operationID,
                        lengthBucket: bucket
                    )
                )
                let material = try learningRepository.replaceAnalysis(
                    result,
                    materialID: input.materialID,
                    operationSummary: LearningMaterialOperationSummary(
                        operationID: operationID,
                        entryID: existingMaterial.entryID,
                        materialID: existingMaterial.id,
                        kind: .analyze,
                        status: .succeeded,
                        failureCategory: nil,
                        promptID: LearningMaterialPromptRegistry.analysisPromptID,
                        promptVersion: LearningMaterialPromptRegistry.promptVersion,
                        providerProfileID: existingMaterial.metadata.providerProfileID,
                        providerEndpointID: existingMaterial.metadata.providerEndpointID,
                        providerPresetID: existingMaterial.metadata.providerPresetID,
                        modelName: existingMaterial.metadata.modelName,
                        inputKind: existingMaterial.inputKind,
                        estimatedTokenBucket: bucket,
                        durationMilliseconds: nil,
                        createdAt: existingMaterial.updatedAt,
                        completedAt: Date()
                    )
                )
                return .generated(material)
            } catch let error as LearningMaterialGenerationServiceError {
                generationLogger.error("analyze failed: \(error.category.rawValue, privacy: .public)")
                try? recordLearningMaterialFailure(
                    error.category,
                    operationID: operationID,
                    materialID: input.materialID,
                    kind: .analyze,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.analysisPromptID,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(error.category)
            } catch let error as AIProviderCredentialStoreError {
                generationLogger.error("analyze failed: credentialMissing — \(String(describing: error), privacy: .public)")
                let category: LearningMaterialGenerationFailureCategory = switch error {
                case .missingCredential, .credentialInaccessible, .credentialCorrupted, .userInteractionRequired:
                    .credentialMissing
                }
                try? recordLearningMaterialFailure(
                    category,
                    operationID: operationID,
                    materialID: input.materialID,
                    kind: .analyze,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.analysisPromptID,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(category)
            } catch {
                generationLogger.error("analyze failed: unknown — \(String(describing: error), privacy: .public)")
                try? recordLearningMaterialFailure(
                    .unknown,
                    operationID: operationID,
                    materialID: input.materialID,
                    kind: .analyze,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.analysisPromptID,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(.unknown)
            }
        },
        recordBlockedOperation: { operationID, entryID, kind, category, bucket in
            do {
                try GRDBLearningContentRepository(database: databaseFactory.database()).recordOperation(
                    .failed(
                        operationID: operationID,
                        entryID: entryID,
                        kind: kind,
                        failureCategory: category,
                        bucket: bucket,
                        createdAt: Date(),
                        completedAt: Date(),
                        promptID: kind == .analyze
                            ? LearningMaterialPromptRegistry.analysisPromptID
                            : LearningMaterialPromptRegistry.generationPromptID,
                        promptVersion: LearningMaterialPromptRegistry.promptVersion
                    )
                )
            } catch {}
        },
        cancelOperation: { operationID, entryID, materialID, kind, bucket in
            do {
                try GRDBLearningContentRepository(database: databaseFactory.database()).recordOperation(
                    .cancelled(
                        operationID: operationID,
                        entryID: entryID,
                        materialID: materialID,
                        kind: kind,
                        bucket: bucket,
                        createdAt: Date(),
                        completedAt: Date(),
                        promptID: kind == .analyze
                            ? LearningMaterialPromptRegistry.analysisPromptID
                            : LearningMaterialPromptRegistry.generationPromptID,
                        promptVersion: LearningMaterialPromptRegistry.promptVersion
                    )
                )
            } catch {}
        }
    )
}

private func resolveLearningMaterialSecret(
    endpoint: AIProviderEndpointInput,
    profile: AIProviderConfigurationProfile,
    credentialStore: any AIProviderCredentialStore
) async throws -> String? {
    guard let credentialID = endpoint.credentialID else {
        return nil
    }
    guard let credential = profile.credentials.first(where: { $0.id == credentialID }) else {
        throw AIProviderCredentialStoreError.missingCredential
    }
    return try await credentialStore.resolveSecret(
        for: AIProviderCredentialKeychainReference(metadata: credential)
    ).value
}

private func credentialResolveFailureCategory(
    for error: AIProviderCredentialStoreError
) -> AIProviderValidationErrorCategory {
    switch error {
    case .missingCredential:
        .missingCredential
    case .credentialInaccessible, .credentialCorrupted, .userInteractionRequired:
        .credentialInaccessible
    }
}

private func recordLearningMaterialFailure(
    _ category: LearningMaterialGenerationFailureCategory,
    operationID: DiagnosticOperationID,
    entryID: String,
    kind: LearningMaterialOperationKind,
    bucket: LearningMaterialEstimatedTokenBucket,
    promptID: String = LearningMaterialPromptRegistry.generationPromptID,
    repository: GRDBLearningContentRepository
) throws {
    try repository.recordOperation(
        .failed(
            operationID: operationID,
            entryID: entryID,
            kind: kind,
            failureCategory: category,
            bucket: bucket,
            createdAt: Date(),
            completedAt: Date(),
            promptID: promptID
        )
    )
}

private func recordLearningMaterialFailure(
    _ category: LearningMaterialGenerationFailureCategory,
    operationID: DiagnosticOperationID,
    materialID: String,
    kind: LearningMaterialOperationKind,
    bucket: LearningMaterialEstimatedTokenBucket,
    promptID: String,
    repository: GRDBLearningContentRepository
) throws {
    guard let material = try repository.material(id: materialID) else {
        return
    }
    try recordLearningMaterialFailure(
        category,
        operationID: operationID,
        entryID: material.entryID,
        kind: kind,
        bucket: bucket,
        promptID: promptID,
        repository: repository
    )
}

private extension AIProviderConfigurationProfile {
    var textGenerationEndpointInput: AIProviderEndpointInput? {
        endpoints.first { endpoint in
            endpoint.purpose == .textGeneration && endpoint.isEnabled
        }.map { endpoint in
            AIProviderEndpointInput(
                id: endpoint.id,
                profileID: endpoint.profileID,
                purpose: endpoint.purpose,
                isEnabled: endpoint.isEnabled,
                providerPresetID: endpoint.providerPresetID,
                adapterKind: endpoint.adapterKind,
                baseURL: endpoint.baseURL,
                modelName: endpoint.modelName,
                credentialID: endpoint.credentialID,
                supportsImageInput: endpoint.supportsImageInput,
                imageInputEnabled: endpoint.imageInputEnabled,
                requestTimeoutSeconds: endpoint.requestTimeoutSeconds
            )
        }
    }
}

private func makeAIProviderConfigurationService(
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore,
    diagnosticLogger: any DiagnosticLogging,
    ttsPreviewStore: any TTSAudioPreviewStore
) throws -> AIProviderConfigurationService {
    try AIProviderConfigurationService(
        repository: GRDBAIProviderConfigurationRepository(database: databaseFactory.database()),
        credentialStore: credentialStore,
        configurationProbeService: AIProviderConfigurationProbeService(
            httpClient: URLSessionAIProviderProbeHTTPClient(),
            diagnosticLogger: diagnosticLogger
        ),
        ttsConfigurationProbeService: TTSConfigurationProbeService(
            httpClient: URLSessionAIProviderProbeHTTPClient(),
            audioValidationService: DefaultTTSAudioValidationService(previewStore: ttsPreviewStore),
            diagnosticLogger: diagnosticLogger
        ),
        embeddingConfigurationProbeService: EmbeddingConfigurationProbeService(
            httpClient: URLSessionAIProviderProbeHTTPClient()
        ),
        diagnosticLogger: diagnosticLogger
    )
}

/// Diagnostics are disabled by default (spec 008); console logging is only attached
/// when the user explicitly opts in through LANGOTRACE_DIAGNOSTICS=1.
func makeDiagnosticLogger(
    databaseFactory: SharedAppDatabaseFactory,
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> any DiagnosticLogging {
    var loggers: [any DiagnosticLogging] = []

    if environment["LANGOTRACE_DIAGNOSTICS"] == "1" {
        loggers.append(
            ConsoleDiagnosticLogger(
                minimumLevel: diagnosticLevel(from: environment["LANGOTRACE_LOG_LEVEL"])
            )
        )
    }

    if environment["LANGOTRACE_DIAGNOSTIC_STORE"] == "1",
       let repository = try? GRDBDiagnosticEventRepository(database: databaseFactory.database())
    {
        loggers.append(RepositoryDiagnosticLogger(repository: repository))
    }

    switch loggers.count {
    case 0:
        return DisabledDiagnosticLogger()
    case 1:
        return loggers[0]
    default:
        return CompositeDiagnosticLogger(loggers: loggers)
    }
}

private func diagnosticLevel(from value: String?) -> DiagnosticLevel {
    switch value {
    case "debug":
        .debug
    case "warning":
        .warning
    case "error":
        .error
    default:
        .info
    }
}

@MainActor
final class AppSessionState: ObservableObject {
    @Published var phase: LangoTraceAppPhase = .welcome
    @Published var onboardingDraft = OnboardingDraft()
    @Published private(set) var currentLanguageSpace: LanguageSpacePreview?
    @Published private(set) var languageSpaces: [LanguageSpace] = []
    @Published private(set) var recoveryState: LanguageSpaceRecoveryState = .idle

    private let languageSpaceRepositoryFactory: @Sendable () throws -> any LanguageSpaceRepository
    private var languageSpaceRepository: (any LanguageSpaceRepository)?

    init(
        languageSpaceRepositoryFactory: @escaping @Sendable () throws -> any LanguageSpaceRepository = {
            EmptyLanguageSpaceRepository()
        }
    ) {
        self.languageSpaceRepositoryFactory = languageSpaceRepositoryFactory
    }

    /// Restores the persisted language spaces and current selection. The method is
    /// intentionally re-runnable from `.failed`: the welcome screen retry button
    /// calls it again after a failed database open or migration.
    func restoreLanguageSpace() {
        guard recoveryState != .restoring else {
            return
        }

        recoveryState = .restoring
        do {
            let repository = try repository()
            let current = try repository.currentLanguageSpace()
            let spaces = try repository.listActiveLanguageSpaces()
            languageSpaces = spaces
            currentLanguageSpace = current?.preview
            recoveryState = .restored
        } catch {
            recoveryState = .failed
            currentLanguageSpace = nil
            languageSpaces = []
        }
    }

    func completeWelcome() {
        guard recoveryState != .restoring, recoveryState != .failed else {
            return
        }
        phase = LaunchRoute.route(hasLanguageSpace: currentLanguageSpace != nil).appPhase
    }

    func createLanguageSpace() {
        // Draft validation failure is not a storage recovery failure: the draft is
        // normalized before producing the input, so in practice this cannot throw.
        // If it ever does, stay on onboarding instead of poisoning `recoveryState`.
        guard let input = try? onboardingDraft.makeLanguageSpaceInput() else {
            return
        }
        addLanguageSpace(input)
        phase = LaunchRoute.route(hasLanguageSpace: currentLanguageSpace != nil).appPhase
    }

    func addLanguageSpace(_ input: CreateLanguageSpaceInput) {
        do {
            let created = try repository().createLanguageSpace(input: input)
            try refreshLanguageSpaces(selecting: created)
        } catch {
            recoveryState = .failed
        }
    }

    func selectLanguageSpace(id: String) {
        do {
            let selected = try repository().selectCurrentLanguageSpace(id: id)
            try refreshLanguageSpaces(selecting: selected)
        } catch {
            recoveryState = .failed
        }
    }

    func updateLanguageSpace(id: String, input: UpdateLanguageSpaceInput) {
        do {
            let updated = try repository().updateLanguageSpace(id: id, input: input)
            try refreshLanguageSpaces(selecting: updated.id == currentLanguageSpace?.id ? updated : nil)
        } catch {
            recoveryState = .failed
        }
    }

    func deleteLanguageSpace(id: String) {
        do {
            let result = try repository().deleteLanguageSpace(id: id)
            try refreshLanguageSpaces(selecting: result.fallbackCurrentSpace)
            if result.remainingActiveCount == 0 {
                phase = .onboarding
            }
        } catch {
            recoveryState = .failed
        }
    }

    private func repository() throws -> any LanguageSpaceRepository {
        if let languageSpaceRepository {
            return languageSpaceRepository
        }
        let repository = try languageSpaceRepositoryFactory()
        languageSpaceRepository = repository
        return repository
    }

    private func refreshLanguageSpaces(selecting selectedSpace: LanguageSpace?) throws {
        let repository = try repository()
        languageSpaces = try repository.listActiveLanguageSpaces()
        if let selectedSpace {
            currentLanguageSpace = selectedSpace.preview
        } else {
            currentLanguageSpace = try repository.currentLanguageSpace()?.preview
        }
        recoveryState = .restored
    }
}

enum LanguageSpaceRecoveryState: Equatable {
    case idle
    case restoring
    case restored
    case failed
}

private extension LaunchRoute {
    var appPhase: LangoTraceAppPhase {
        switch self {
        case .onboarding:
            .onboarding
        case .main:
            .main
        }
    }
}
