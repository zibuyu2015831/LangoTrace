import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import LangoTraceUI
import SwiftUI

struct AppEnvironment {
    let languageSpaceRepository: any LanguageSpaceRepository
    let learningContentRepository: any LearningContentRepository
    let aiProvider: any AIProvider
    let speechService: any SpeechService
    let syncService: any SyncService

    static func bootstrap() -> AppEnvironment {
        AppEnvironment(
            languageSpaceRepository: EmptyLanguageSpaceRepository(),
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

    func completeWelcome() {
        phase = LaunchRoute.route(hasLanguageSpace: currentLanguageSpace != nil).appPhase
    }

    func createLanguageSpace() {
        currentLanguageSpace = onboardingDraft.makeLanguageSpacePreview()
        phase = .main
    }
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
