import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import LangoTraceUI
import SwiftUI

struct AppEnvironment {
    let makeLanguageSpaceRepository: @Sendable () throws -> any LanguageSpaceRepository
    let learningContentRepository: any LearningContentRepository
    let learningMaterialGenerationActions: LearningMaterialGenerationActions
    let aiProviderSettingsActions: AIProviderSettingsActions
    let aiProvider: any AIProvider
    let speechService: any SpeechService
    let syncService: any SyncService

    static func bootstrap() -> AppEnvironment {
        let databaseFactory = SharedAppDatabaseFactory()
        let credentialStore = KeychainAIProviderCredentialStore()
        let diagnosticLogger = makeDiagnosticLogger(databaseFactory: databaseFactory)
        let learningContentRepository = makeLearningContentRepository(databaseFactory: databaseFactory)

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
            aiProviderSettingsActions: AIProviderSettingsActions(
                loadDefaultProfile: {
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger
                    )
                    return try await service.loadDefaultProfile()
                },
                resolveCredentialSecret: { credential in
                    let secret = try await credentialStore.resolveSecret(
                        for: AIProviderCredentialKeychainReference(metadata: credential)
                    )
                    return secret.value
                },
                saveDefaultProfile: { input, operationID in
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger
                    )
                    return try await service.saveDefaultProfile(input, operationID: operationID)
                },
                validateDefaultProfileCredentials: {
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger
                    )
                    return try await service.validateDefaultProfileCredentials()
                },
                testProviderConfiguration: { source, snapshot, languageContext, operationID in
                    let service = try makeAIProviderConfigurationService(
                        databaseFactory: databaseFactory,
                        credentialStore: credentialStore,
                        diagnosticLogger: diagnosticLogger
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
                recordDiagnosticEvent: { event in
                    await diagnosticLogger.record(event)
                }
            ),
            aiProvider: DisabledAIProvider(),
            speechService: DisabledSpeechService(),
            syncService: DisabledSyncService()
        )
    }
}

private func makeLearningContentRepository(
    databaseFactory: SharedAppDatabaseFactory
) -> any LearningContentRepository {
    do {
        return try GRDBLearningContentRepositoryBridge(
            repository: GRDBLearningContentRepository(database: databaseFactory.database())
        )
    } catch {
        return InMemoryLearningContentRepository(seedEntries: [])
    }
}

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
                    try recordLearningMaterialFailure(
                        .providerNotConfigured,
                        operationID: operationID,
                        input: input,
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
                let material = try learningRepository.saveGeneratedMaterial(result, for: input.entryID)
                try learningRepository.recordOperation(
                    LearningMaterialOperationSummary(
                        operationID: operationID,
                        entryID: input.entryID,
                        materialID: material.id,
                        kind: .generate,
                        status: .succeeded,
                        failureCategory: nil,
                        promptID: material.metadata.promptID,
                        promptVersion: material.metadata.promptVersion,
                        providerProfileID: material.metadata.providerProfileID,
                        providerEndpointID: material.metadata.providerEndpointID,
                        providerPresetID: material.metadata.providerPresetID,
                        modelName: material.metadata.modelName,
                        inputKind: material.inputKind,
                        estimatedTokenBucket: bucket,
                        durationMilliseconds: nil,
                        createdAt: material.createdAt,
                        completedAt: Date()
                    )
                )
                return .generated(material)
            } catch let error as LearningMaterialGenerationServiceError {
                try? recordLearningMaterialFailure(
                    error.category,
                    operationID: operationID,
                    input: input,
                    bucket: bucket,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(error.category)
            } catch let error as AIProviderCredentialStoreError {
                let category: LearningMaterialGenerationFailureCategory
                switch error {
                case .missingCredential, .credentialInaccessible, .credentialCorrupted, .userInteractionRequired:
                    category = .credentialMissing
                }
                try? recordLearningMaterialFailure(
                    category,
                    operationID: operationID,
                    input: input,
                    bucket: bucket,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(category)
            } catch {
                try? recordLearningMaterialFailure(
                    .unknown,
                    operationID: operationID,
                    input: input,
                    bucket: bucket,
                    repository: GRDBLearningContentRepository(database: databaseFactory.database())
                )
                return .failed(.unknown)
            }
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

private func recordLearningMaterialFailure(
    _ category: LearningMaterialGenerationFailureCategory,
    operationID: DiagnosticOperationID,
    input: LearningMaterialGenerationInput,
    bucket: LearningMaterialEstimatedTokenBucket,
    repository: GRDBLearningContentRepository
) throws {
    try repository.recordOperation(
        .failed(
            operationID: operationID,
            entryID: input.entryID,
            kind: .generate,
            failureCategory: category,
            bucket: bucket,
            completedAt: Date()
        )
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

private final class SharedAppDatabaseFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedDatabase: AppDatabase?

    func database() throws -> AppDatabase {
        lock.lock()
        defer { lock.unlock() }

        if let cachedDatabase {
            return cachedDatabase
        }
        let database = try AppDatabase.persistent(
            at: LanguageSpaceDatabaseLocation.defaultDatabaseURL()
        )
        cachedDatabase = database
        return database
    }
}

private func makeAIProviderConfigurationService(
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore,
    diagnosticLogger: any DiagnosticLogging
) throws -> AIProviderConfigurationService {
    try AIProviderConfigurationService(
        repository: GRDBAIProviderConfigurationRepository(database: databaseFactory.database()),
        credentialStore: credentialStore,
        configurationProbeService: AIProviderConfigurationProbeService(
            httpClient: URLSessionAIProviderProbeHTTPClient(),
            diagnosticLogger: diagnosticLogger
        ),
        diagnosticLogger: diagnosticLogger
    )
}

private func makeDiagnosticLogger(
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

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment = .bootstrap()
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
        do {
            let input = try onboardingDraft.makeLanguageSpaceInput()
            addLanguageSpace(input)
            phase = LaunchRoute.route(hasLanguageSpace: currentLanguageSpace != nil).appPhase
        } catch {
            recoveryState = .failed
        }
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
