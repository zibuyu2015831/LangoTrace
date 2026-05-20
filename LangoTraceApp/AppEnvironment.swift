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
    let aiProvider: any AIProvider
    let speechService: any SpeechService
    let syncService: any SyncService

    static func bootstrap() -> AppEnvironment {
        AppEnvironment(
            makeLanguageSpaceRepository: {
                try GRDBLanguageSpaceRepository.persistent(
                    at: LanguageSpaceDatabaseLocation.defaultDatabaseURL()
                )
            },
            learningContentRepository: InMemoryLearningContentRepository(seedEntries: []),
            aiProvider: DisabledAIProvider(),
            speechService: DisabledSpeechService(),
            syncService: DisabledSyncService()
        )
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
