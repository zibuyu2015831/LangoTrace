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
        mainWindowScene

        #if os(macOS)
            Settings {
                LangoTraceSettingsSceneView(capabilities: settingsCapabilities)
                    .environment(\.locale, Locale(identifier: resolvedInterfaceLanguageCode))
                    .environment(\.appEnvironment, environment)
            }
        #endif
    }

    @SceneBuilder
    private var mainWindowScene: some Scene {
        #if os(macOS)
            WindowGroup {
                rootContent
            }
            .windowResizability(.contentSize)
            .commands {
                LangoTraceCommands()
            }
        #else
            WindowGroup {
                rootContent
            }
        #endif
    }

    private var rootContent: some View {
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
        .environment(\.locale, Locale(identifier: resolvedInterfaceLanguageCode))
        .environment(\.appEnvironment, environment)
    }

    private var resolvedInterfaceLanguageCode: String {
        interfaceLanguagePreference.resolvedLanguageCode(
            systemLanguageCodes: Bundle.main.preferredLocalizations
        )
    }

    private var settingsCapabilities: [SettingsCapability] {
        environment.learningContentRepository.settingsCapabilities(
            for: session.currentLanguageSpace?.id ?? "bootstrap"
        )
    }
}

#if os(macOS)
    private struct LangoTraceCommands: Commands {
        @Environment(\.openSettings) private var openSettings

        var body: some Commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    post(LangoTraceAppCommand.newEntry)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    post(LangoTraceAppCommand.showSettings)
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Workspace") {
                Button("Search") {
                    post(LangoTraceAppCommand.search)
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("Toggle Sidebar") {
                    post(LangoTraceAppCommand.toggleSidebar)
                }
                .keyboardShortcut("[", modifiers: [.command, .option])

                Button("Toggle Inspector") {
                    post(LangoTraceAppCommand.toggleInspector)
                }
                .keyboardShortcut("]", modifiers: [.command, .option])
            }
        }

        private func post(_ command: Notification.Name) {
            NotificationCenter.default.post(name: command, object: nil)
        }
    }
#endif
