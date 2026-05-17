import LangoTraceAI
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import SwiftUI

struct AppEnvironment {
    let languageSpaceRepository: any LanguageSpaceRepository
    let aiProvider: any AIProvider
    let speechService: any SpeechService
    let syncService: any SyncService

    static func bootstrap() -> AppEnvironment {
        AppEnvironment(
            languageSpaceRepository: EmptyLanguageSpaceRepository(),
            aiProvider: DisabledAIProvider(),
            speechService: DisabledSpeechService(),
            syncService: DisabledSyncService()
        )
    }
}

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment = .bootstrap()
}
