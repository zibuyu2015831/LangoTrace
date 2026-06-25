import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceLearnerModel
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
    let photoDisplayActions: PhotoDisplayActions
    let aiProviderSettingsActions: AIProviderSettingsActions
    let aiRequestPreviewActions: AIRequestPreviewActions
    let aiRequestLogActions: AIRequestLogActions
    let localSearchActions: LocalSearchActions
    let memoryDepositActions: MemoryDepositActions
    let memoryReviewActions: MemoryReviewActions
    // LM02 Slice 1: learner profile overview seam (snapshot load + Memory governance).
    let learnerProfileActions: LearnerProfileActions
    let syncService: any SyncService
    // LM01: the Learner Model seam is assembled here so LM02's overview UI can consume
    // Ability knowledge coverage without re-wiring. No UI reads it yet (compute-on-read,
    // pure local; nil when the database is unavailable).
    let learnerContextProvider: (any LearnerContextProvider)?
    // LM02-S2: Style surface-imprint seam assembled as forward infrastructure
    // (seam-only, user decision 2026-06-25). No consumer reads it yet — the
    // companion v2 / rewrite slices will. Compute-on-read, pure local.
    let learnerStyleProvider: (any LearnerStyleProvider)?
    // E12: recomputes settings row values (AI provider / sync / local data) off the main
    // thread from non-sensitive snapshots only — never Keychain plaintext, never a probe.
    let loadSettingsStatus: @Sendable () async -> SettingsStatusProjection

    // AppEnvironment assembles the cross-package production graph in one place.
    // swiftlint:disable:next function_body_length cyclomatic_complexity
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

        // E6/E5-Slice2: local, non-sensitive AI request log recorder (built early
        // so practice actions can write critique request logs).
        let aiRequestLogRepository: (any AIRequestLogRepository)? =
            (try? databaseFactory.database()).map { GRDBAIRequestLogRepository(database: $0) }
        let aiRequestLogRecorder = AIRequestLogRecorder(repository: aiRequestLogRepository)

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
                diagnosticLogger: diagnosticLogger,
                credentialStore: credentialStore,
                aiRequestLogRecorder: aiRequestLogRecorder
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
            photoWritingActions = PhotoWritingActionsAssembly.makeActions(
                database: database,
                fileStore: fileStore,
                credentialStore: credentialStore,
                aiRequestLogRecorder: aiRequestLogRecorder
            )
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

        let photoDisplayActions: PhotoDisplayActions
        do {
            let database = try databaseFactory.database()
            let mediaRoot = try SentenceAudioPlaybackAssembly.defaultMediaArtifactsRoot()
            let fileStore = try LocalMediaArtifactFileStore(rootDirectory: mediaRoot)
            let attachmentRepo = GRDBEntryPhotoAttachmentRepository(database: database)
            photoDisplayActions = PhotoDisplayActions { entryID in
                guard let relativePath = try? attachmentRepo.photoRelativePath(forEntryID: entryID),
                      let url = try? fileStore.absoluteURLForInternalUse(relativePath: relativePath)
                else { return nil }
                return try? Data(contentsOf: url)
            }
        } catch {
            photoDisplayActions = .disabled
            recordBootstrapComponentFailure(
                component: "photo_display_actions",
                error: error,
                name: .aiProviderConfigurationDatabaseWriteFailed,
                domain: .dataStorage,
                diagnosticLogger: diagnosticLogger
            )
        }

        // E6: same-source preview seam (request log recorder built earlier above).
        let aiRequestPreviewEndpointCache = AIRequestPreviewEndpointCache()
        // Warm the cache so the iPad / macOS preview card can show the real
        // configured provider + model; until loaded / when unconfigured the card
        // falls back to the explicit offline state.
        Task {
            guard let database = try? databaseFactory.database() else { return }
            let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
            let profile = try? await configurationRepository.loadDefaultProfile()
            aiRequestPreviewEndpointCache.set(profile?.textGenerationEndpointInput)
        }
        let aiRequestPreviewActions = AIRequestPreviewActions { entry in
            guard let endpoint = aiRequestPreviewEndpointCache.current() else { return nil }
            return .learningMaterialGeneration(
                endpoint: endpoint,
                lengthBucket: AIRequestLengthBucket(characterCount: entry.body.count)
            )
        }
        let aiRequestLogActions = AIRequestLogActions {
            guard let repository = aiRequestLogRepository else { return [] }
            return await (try? repository.recentAll(limit: 100)) ?? []
        }

        // E9: local FTS search (rebuildable derived data; rebuild-on-open).
        let localSearchRepository: (any LocalSearchRepository)? =
            (try? databaseFactory.database()).map { GRDBLocalSearchRepository(database: $0) }
        let localSearchActions = LocalSearchActions(
            search: { query, spaceID in
                guard let localSearchRepository else { return .empty(query: query) }
                return await (try? localSearchRepository.search(query: query, spaceID: spaceID, perGroupLimit: 5))
                    ?? .empty(query: query)
            },
            rebuildIndex: { spaceID in
                guard let localSearchRepository else { return }
                try? await localSearchRepository.rebuildSearchIndex(spaceID: spaceID)
            }
        )

        // E7: memory deposit (user main data; explicit "add to memory" action).
        let memoryItemRepository: (any MemoryItemRepository)? =
            (try? databaseFactory.database()).map { GRDBMemoryItemRepository(database: $0) }

        // LM01: Learner Model Ability coverage (compute-on-read, pure local).
        let learnerContextProvider: (any LearnerContextProvider)? =
            (try? databaseFactory.database()).map { GRDBLearnerContextProvider(reader: $0.reader) }

        // LM02-S2: Style surface-imprint provider (seam-only, no consumer yet).
        let learnerStyleProvider: (any LearnerStyleProvider)? =
            (try? databaseFactory.database()).map { GRDBLearnerStyleProvider(reader: $0.reader) }

        // E12: settings status projection. Reads only the non-sensitive config snapshot and
        // the on-disk footprint; the sync value comes from the (disabled) sync service.
        let settingsConfigRepository: GRDBAIProviderConfigurationRepository? =
            (try? databaseFactory.database()).map { GRDBAIProviderConfigurationRepository(database: $0) }
        let settingsUsageService: LocalDataUsageService? = {
            guard let settingsDatabaseURL = databaseURL ?? (try? LanguageSpaceDatabaseLocation.defaultDatabaseURL()),
                  let settingsMediaArtifactsRoot = try? SentenceAudioPlaybackAssembly.defaultMediaArtifactsRoot()
            else { return nil }
            return LocalDataUsageService(
                databaseURL: settingsDatabaseURL,
                mediaArtifactsRoot: settingsMediaArtifactsRoot
            )
        }()
        let settingsSyncService = DisabledSyncService()
        let syncEnabledSnapshot = settingsSyncService.isEnabled
        let loadSettingsStatus: @Sendable () async -> SettingsStatusProjection = {
            var aiProvider: AIProviderListStatus = .notConfigured
            if let settingsConfigRepository {
                aiProvider = await SettingsCapabilityProjectionService(
                    configurationRepository: settingsConfigRepository
                ).aiProviderStatus()
            }
            let localData = await settingsUsageService?.computeUsage()
            return SettingsStatusProjection(
                aiProvider: aiProvider,
                sync: SyncListStatus.make(isEnabled: syncEnabledSnapshot),
                localData: localData
            )
        }
        let memoryDepositActions = MemoryDepositActions(
            depositCandidate: { candidateID, spaceID in
                guard let memoryItemRepository else { return false }
                return await ((try? memoryItemRepository.depositCandidate(candidateID: candidateID, spaceID: spaceID)) ?? nil) != nil
            },
            listDeposited: { spaceID in
                guard let memoryItemRepository else { return [] }
                return await (try? memoryItemRepository.listMemoryItems(spaceID: spaceID)) ?? []
            },
            depositedCandidateIDs: { spaceID in
                guard let memoryItemRepository else { return [] }
                return await (try? memoryItemRepository.depositedCandidateIDs(spaceID: spaceID)) ?? []
            },
            depositedEntryIDs: { spaceID in
                guard let memoryItemRepository else { return [] }
                return await (try? memoryItemRepository.depositedEntryIDs(spaceID: spaceID)) ?? []
            }
        )

        // E8: local memory review queue (fixed-interval scheduler over E7 columns).
        let memoryReviewActions = makeMemoryReviewActions(memoryItemRepository: memoryItemRepository)

        let learnerProfileActions = makeLearnerProfileActions(
            databaseFactory: databaseFactory,
            learnerContextProvider: learnerContextProvider,
            memoryItemRepository: memoryItemRepository
        )
        return AppEnvironment(
            makeLanguageSpaceRepository: {
                try GRDBLanguageSpaceRepository(
                    database: databaseFactory.database()
                )
            },
            learningContentRepository: learningContentRepository,
            learningMaterialGenerationActions: makeLearningMaterialGenerationActions(
                databaseFactory: databaseFactory,
                credentialStore: credentialStore,
                aiRequestLogRecorder: aiRequestLogRecorder
            ),
            sentenceAudioPlaybackActions: sentenceAudioPlaybackCoordinatorBox.actions(),
            readingLibraryActions: makeReadingLibraryActions(databaseFactory: databaseFactory),
            readingExplanationAction: makeReadingExplanationAction(
                databaseFactory: databaseFactory,
                credentialStore: credentialStore,
                aiRequestLogRecorder: aiRequestLogRecorder
            ),
            readingTTSAction: makeReadingTTSAction(
                sentenceAudioPlaybackActions: sentenceAudioPlaybackCoordinatorBox.actions()
            ),
            readingCacheStorage: readingCacheStorage,
            practiceActions: practiceActions,
            photoWritingActions: photoWritingActions,
            photoDisplayActions: photoDisplayActions,
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
            aiRequestPreviewActions: aiRequestPreviewActions,
            aiRequestLogActions: aiRequestLogActions,
            localSearchActions: localSearchActions,
            memoryDepositActions: memoryDepositActions,
            memoryReviewActions: memoryReviewActions,
            learnerProfileActions: learnerProfileActions,
            syncService: DisabledSyncService(),
            learnerContextProvider: learnerContextProvider,
            learnerStyleProvider: learnerStyleProvider,
            loadSettingsStatus: loadSettingsStatus
        )
    }
}

/// Thread-safe holder for the cached default text-generation endpoint that backs
/// the synchronous preview-card projection seam (mirrors the locked-box pattern
/// E0a adopted over `nonisolated(unsafe) static var`).
final class AIRequestPreviewEndpointCache: @unchecked Sendable {
    private let lock = NSLock()
    private var endpoint: AIProviderEndpointInput?

    func set(_ endpoint: AIProviderEndpointInput?) {
        lock.lock()
        defer { lock.unlock() }
        self.endpoint = endpoint
    }

    func current() -> AIProviderEndpointInput? {
        lock.lock()
        defer { lock.unlock() }
        return endpoint
    }
}

private func makeReadingExplanationAction(
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore,
    aiRequestLogRecorder: AIRequestLogRecorder
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
        let serviceRequest = ReadingSelectionExplanationServiceRequest(
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
        let service = ReadingSelectionExplanationService(httpClient: URLSessionAIProviderHTTPClient())
        func recordRequestLog(_ outcome: AIRequestLogOutcome) async {
            await aiRequestLogRecorder.record(
                serviceRequest.makeLogEntry(id: UUID().uuidString, outcome: outcome, createdAt: Date())
            )
        }
        do {
            let result = try await service.explain(serviceRequest)
            recorder.record(.succeeded, profile: profile, endpoint: endpoint)
            await recordRequestLog(.success)
            return result
        } catch let error as CancellationError {
            recorder.record(.cancelled, profile: profile, endpoint: endpoint)
            await recordRequestLog(.cancelled)
            throw error
        } catch let error as ReadingSelectionExplanationServiceError {
            recorder.record(.failed(category: "\(error.category)"), profile: profile, endpoint: endpoint)
            await recordRequestLog(
                error.category == .cancelled ? .cancelled : .failed(AIRequestLogFailureBucket(error.category))
            )
            throw error
        } catch {
            recorder.record(.failed(category: "providerRejected"), profile: profile, endpoint: endpoint)
            await recordRequestLog(.failed(.providerRejected))
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
        },
        setFavorite: { id, spaceID, isFavorite in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            try repository.setFavorite(documentID: id, spaceID: spaceID, isFavorite: isFavorite)
        },
        updateReadingProgress: { id, spaceID, percent, blockIndex, characterOffset, structureVersion, contentRevision, completedAt in
            let repository = try GRDBReadingLibraryRepository(database: databaseFactory.database())
            try repository.updateReadingProgress(
                documentID: id, spaceID: spaceID,
                percent: percent, blockIndex: blockIndex, characterOffset: characterOffset,
                structureVersion: structureVersion, contentRevision: contentRevision,
                completedAt: completedAt
            )
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
    credentialStore: any AIProviderCredentialStore,
    aiRequestLogRecorder: AIRequestLogRecorder
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
                    await aiRequestLogRecorder.recordLearningMaterial(
                        operationID: operationID,
                        endpoint: nil,
                        bucket: bucket,
                        promptID: LearningMaterialPromptRegistry.generationPromptID,
                        outcome: .failed(.providerNotConfigured)
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: endpoint,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.generationPromptID,
                    outcome: .success
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: nil,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.generationPromptID,
                    outcome: AIRequestLogRecorder.outcome(for: error.category)
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: nil,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.generationPromptID,
                    outcome: .failed(AIRequestLogFailureBucket(category))
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: nil,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.generationPromptID,
                    outcome: .failed(.unknown)
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
                    await aiRequestLogRecorder.recordLearningMaterial(
                        operationID: operationID,
                        endpoint: nil,
                        bucket: bucket,
                        promptID: LearningMaterialPromptRegistry.analysisPromptID,
                        outcome: .failed(.providerNotConfigured)
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: endpoint,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.analysisPromptID,
                    outcome: .success
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: nil,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.analysisPromptID,
                    outcome: AIRequestLogRecorder.outcome(for: error.category)
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: nil,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.analysisPromptID,
                    outcome: .failed(AIRequestLogFailureBucket(category))
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
                await aiRequestLogRecorder.recordLearningMaterial(
                    operationID: operationID,
                    endpoint: nil,
                    bucket: bucket,
                    promptID: LearningMaterialPromptRegistry.analysisPromptID,
                    outcome: .failed(.unknown)
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

func resolveLearningMaterialSecret(
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

extension AIProviderConfigurationProfile {
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
