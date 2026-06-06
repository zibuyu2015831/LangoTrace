import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import LangoTraceUI
import SwiftUI

@main
struct LangoTraceApp: App {
    private let environment: AppEnvironment
    private let interfaceLanguagePreferenceStore: UserDefaultsInterfaceLanguageStore
    private let appearancePreferenceStore: UserDefaultsAppearancePreferenceStore
    @StateObject private var session: AppSessionState
    @State private var interfaceLanguagePreference: InterfaceLanguagePreference
    @State private var appearancePreference: AppearancePreference

    init() {
        let environment = AppEnvironment.bootstrap()
        let store = UserDefaultsInterfaceLanguageStore()
        let appearanceStore = UserDefaultsAppearancePreferenceStore()
        self.environment = environment
        interfaceLanguagePreferenceStore = store
        appearancePreferenceStore = appearanceStore
        _session = StateObject(
            wrappedValue: AppSessionState(
                languageSpaceRepositoryFactory: environment.makeLanguageSpaceRepository
            )
        )
        _interfaceLanguagePreference = State(initialValue: store.preference)
        _appearancePreference = State(initialValue: appearanceStore.preference)
    }

    var body: some Scene {
        mainWindowScene

        #if os(macOS)
            Settings {
                LangoTraceSettingsSceneView(
                    capabilities: settingsCapabilities,
                    languageSpace: session.currentLanguageSpace,
                    languageSpaces: session.languageSpaces,
                    interfaceLanguagePreference: interfaceLanguagePreference,
                    appearancePreference: appearancePreference,
                    onAddLanguageSpace: session.addLanguageSpace,
                    onSelectLanguageSpace: session.selectLanguageSpace,
                    onUpdateLanguageSpace: session.updateLanguageSpace,
                    onDeleteLanguageSpace: session.deleteLanguageSpace,
                    onInterfaceLanguagePreferenceChange: { preference in
                        interfaceLanguagePreferenceStore.preference = preference
                        interfaceLanguagePreference = preference
                    },
                    onAppearancePreferenceChange: { preference in
                        applyAppearancePreference(preference)
                    }
                )
                .environment(\.locale, Locale(identifier: resolvedInterfaceLanguageCode))
                .environment(\.appEnvironment, environment)
                .environment(\.aiProviderSettingsActions, environment.aiProviderSettingsActions)
                .preferredColorScheme(appearancePreference.preferredColorScheme)
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
            languageSpaces: session.languageSpaces,
            learningContentRepository: environment.learningContentRepository,
            learningMaterialGenerationActions: environment.learningMaterialGenerationActions,
            sentenceAudioPlaybackActions: environment.sentenceAudioPlaybackActions,
            readingLibraryActions: environment.readingLibraryActions,
            readingExplanationAction: environment.readingExplanationAction,
            readingTTSAction: environment.readingTTSAction,
            readingCacheRepository: environment.readingCacheRepository,
            practiceActions: environment.practiceActions,
            interfaceLanguagePreference: interfaceLanguagePreference,
            appearancePreference: appearancePreference,
            onboardingDraft: Binding(
                get: { session.onboardingDraft },
                set: { session.onboardingDraft = $0 }
            ),
            onWelcomeFinished: session.completeWelcome,
            onCreateLanguageSpace: session.createLanguageSpace,
            onAddLanguageSpace: session.addLanguageSpace,
            onSelectLanguageSpace: session.selectLanguageSpace,
            onUpdateLanguageSpace: session.updateLanguageSpace,
            onDeleteLanguageSpace: session.deleteLanguageSpace,
            onInterfaceLanguagePreferenceChange: { preference in
                interfaceLanguagePreferenceStore.preference = preference
                interfaceLanguagePreference = preference
            },
            onAppearancePreferenceChange: { preference in
                applyAppearancePreference(preference)
            }
        )
        .environment(\.locale, Locale(identifier: resolvedInterfaceLanguageCode))
        .environment(\.appEnvironment, environment)
        .environment(\.aiProviderSettingsActions, environment.aiProviderSettingsActions)
        .preferredColorScheme(appearancePreference.preferredColorScheme)
        .task {
            session.restoreLanguageSpace()
        }
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

    private func applyAppearancePreference(_ preference: AppearancePreference) {
        guard appearancePreference != preference else {
            return
        }
        appearancePreferenceStore.preference = preference
        appearancePreference = preference
    }
}

private extension AppearancePreference {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
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
