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
    let aiProviderSettingsActions: AIProviderSettingsActions
    let aiProvider: any AIProvider
    let speechService: any SpeechService
    let syncService: any SyncService

    static func bootstrap() -> AppEnvironment {
        let databaseFactory = SharedAppDatabaseFactory()
        let credentialStore = KeychainAIProviderCredentialStore()
        let diagnosticLogger = makeDiagnosticLogger(databaseFactory: databaseFactory)

        return AppEnvironment(
            makeLanguageSpaceRepository: {
                try GRDBLanguageSpaceRepository(
                    database: databaseFactory.database()
                )
            },
            learningContentRepository: InMemoryLearningContentRepository(seedEntries: []),
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
