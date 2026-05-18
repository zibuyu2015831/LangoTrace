import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview
    @ObservedObject var contentStore: LearningContentStore
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void

    @State private var selectedTab: PhoneRootTab = .today
    @State private var navigationPath: [PhoneRoute] = []
    @State private var presentedSheet: PhoneSheet?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                TodayView(
                    languageSpace: languageSpace,
                    entries: entries,
                    renderingForEntry: rendering(for:),
                    onNewEntry: { presentedSheet = .entryEditor },
                    onPhotoWriting: { presentedSheet = .unavailable(.photoWriting) },
                    onListenOne: { presentedSheet = .unavailable(.listenOne) },
                    onLanguageSpaceAction: { presentedSheet = .unavailable(.languageSwitcher) },
                    onSelectEntry: showEntryDetail
                )
                .tabItem {
                    Label {
                        localizedText(PhoneRootTab.today.localizedTitleKey)
                    } icon: {
                        Image(systemName: "sun.max")
                    }
                }
                .tag(PhoneRootTab.today)

                EntriesView(
                    languageSpace: languageSpace,
                    entries: entries,
                    onNewEntry: { presentedSheet = .entryEditor },
                    onLanguageSpaceAction: { presentedSheet = .unavailable(.languageSwitcher) },
                    onSelectEntry: showEntryDetail
                )
                .tabItem {
                    Label {
                        localizedText(PhoneRootTab.entries.localizedTitleKey)
                    } icon: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                .tag(PhoneRootTab.entries)

                PracticeView(
                    languageSpace: languageSpace,
                    entries: entries,
                    contentStore: contentStore,
                    onLanguageSpaceAction: { presentedSheet = .unavailable(.languageSwitcher) },
                    onPractice: { entry in navigationPath.append(.practice(entry.id)) }
                )
                .tabItem {
                    Label {
                        localizedText(PhoneRootTab.practice.localizedTitleKey)
                    } icon: {
                        Image(systemName: "waveform")
                    }
                }
                .tag(PhoneRootTab.practice)

                MemoryView(
                    languageSpace: languageSpace,
                    memoryItems: contentStore.memoryItems,
                    onLanguageSpaceAction: { presentedSheet = .unavailable(.languageSwitcher) }
                )
                .tabItem {
                    Label {
                        localizedText(PhoneRootTab.memory.localizedTitleKey)
                    } icon: {
                        Image(systemName: "archivebox")
                    }
                }
                .tag(PhoneRootTab.memory)

                SettingsView(
                    languageSpace: languageSpace,
                    capabilities: contentStore.settingsCapabilities,
                    onLanguageSpaceAction: { presentedSheet = .unavailable(.languageSwitcher) },
                    onSelectCapability: { kind in navigationPath.append(.settings(kind)) }
                )
                .tabItem {
                    Label {
                        localizedText(PhoneRootTab.settings.localizedTitleKey)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                .tag(PhoneRootTab.settings)
            }
            .phoneTabBarBackground()
            .navigationDestination(for: PhoneRoute.self) { route in
                switch route {
                case let .entryDetail(entryID):
                    if let entry = entry(id: entryID) {
                        EntryDetailView(
                            languageSpace: languageSpace,
                            entry: entry,
                            rendering: rendering(for: entry),
                            practiceItems: contentStore.practiceItems(for: entry),
                            onPractice: { navigationPath.append(.practice(entry.id)) }
                        )
                    }
                case let .practice(entryID):
                    if let entry = entry(id: entryID) {
                        PracticeSessionView(
                            entry: entry,
                            rendering: rendering(for: entry),
                            session: contentStore.practiceSession(for: entry)
                        )
                    }
                case let .settings(kind):
                    if let capability = capability(kind: kind) {
                        SettingsCapabilityDetailView(
                            languageSpace: languageSpace,
                            capability: capability,
                            interfaceLanguagePreference: interfaceLanguagePreference,
                            onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
                        )
                    }
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .entryEditor:
                    EntryEditorView(languageSpace: languageSpace) { title, body in
                        let entry = contentStore.createEntry(
                            title: title,
                            body: body,
                            source: .typedText
                        )
                        presentedSheet = nil
                        navigationPath.append(.entryDetail(entry.id))
                    }
                case let .unavailable(action):
                    UnavailableCapabilityView(content: action.content)
                        .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                contentStore.ensureSeeded()
            }
        }
    }

    private var entries: [LearningEntry] {
        contentStore.entries
    }

    private func entry(id: String) -> LearningEntry? {
        contentStore.entry(id: id)
    }

    private func rendering(for entry: LearningEntry) -> LearningRendering? {
        contentStore.rendering(for: entry)
    }

    private func capability(kind: SettingsCapability.Kind) -> SettingsCapability? {
        contentStore.capability(kind: kind)
    }

    private func showEntryDetail(_ entry: LearningEntry) {
        contentStore.selectEntry(entry)
        navigationPath.append(.entryDetail(entry.id))
    }
}

private enum PhoneRoute: Hashable {
    case entryDetail(String)
    case practice(String)
    case settings(SettingsCapability.Kind)
}

private enum PhoneSheet: Identifiable {
    case entryEditor
    case unavailable(PhoneUnavailableAction)

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        case let .unavailable(action):
            "unavailable-\(action.rawValue)"
        }
    }
}

private extension View {
    @ViewBuilder
    func phoneTabBarBackground() -> some View {
        #if os(iOS)
            toolbarBackground(LangoTraceDesign.ColorToken.surfaceBase, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        #else
            self
        #endif
    }
}
