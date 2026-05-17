import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import LangoTraceUI
import SwiftUI

@main
struct LangoTraceApp: App {
    private let environment = AppEnvironment.bootstrap()
    private let interfaceLanguagePreferenceStore: UserDefaultsInterfaceLanguageStore
    @StateObject private var session = AppSessionState()
    @State private var interfaceLanguagePreference: InterfaceLanguagePreference

    init() {
        let store = UserDefaultsInterfaceLanguageStore()
        interfaceLanguagePreferenceStore = store
        _interfaceLanguagePreference = State(initialValue: store.preference)
    }

    var body: some Scene {
        WindowGroup {
            let resolvedLanguageCode = interfaceLanguagePreference.resolvedLanguageCode(
                systemLanguageCodes: Locale.preferredLanguages
            )

            LangoTraceRootView(
                phase: session.phase,
                languageSpace: session.currentLanguageSpace,
                learningContentRepository: environment.learningContentRepository,
                interfaceLanguagePreference: interfaceLanguagePreference,
                onboardingDraft: Binding(
                    get: { session.onboardingDraft },
                    set: { session.onboardingDraft = $0 }
                ),
                onWelcomeFinished: session.completeWelcome,
                onCreateLanguageSpace: session.createLanguageSpace,
                onInterfaceLanguagePreferenceChange: { preference in
                    interfaceLanguagePreferenceStore.preference = preference
                    interfaceLanguagePreference = preference
                }
            )
            .environment(\.locale, Locale(identifier: resolvedLanguageCode))
            .environment(\.appEnvironment, environment)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
