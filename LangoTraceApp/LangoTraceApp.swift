import LangoTraceAI
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import LangoTraceUI
import SwiftUI

@main
struct LangoTraceApp: App {
    private let environment = AppEnvironment.bootstrap()
    @StateObject private var session = AppSessionState()

    var body: some Scene {
        WindowGroup {
            LangoTraceRootView(
                phase: session.phase,
                languageSpace: session.currentLanguageSpace,
                learningContentRepository: environment.learningContentRepository,
                onboardingDraft: Binding(
                    get: { session.onboardingDraft },
                    set: { session.onboardingDraft = $0 }
                ),
                onWelcomeFinished: session.completeWelcome,
                onCreateLanguageSpace: session.createLanguageSpace
            )
            .environment(\.appEnvironment, environment)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
