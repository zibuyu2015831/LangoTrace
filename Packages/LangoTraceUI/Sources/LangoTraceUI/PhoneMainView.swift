import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview
    let contentRepository: InMemoryLearningContentRepository
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void

    @State private var selectedTab: PhoneRootTab = .today
    @State private var navigationPath: [PhoneRoute] = []
    @State private var presentedSheet: PhoneSheet?
    @State private var contentRevision = 0

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
                    repository: contentRepository,
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
                    memoryItems: contentRepository.memoryItems(for: languageSpace.id),
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
                    capabilities: contentRepository.settingsCapabilities(for: languageSpace.id),
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
                            practiceItems: contentRepository.practiceItems(for: entry.id),
                            onPractice: { navigationPath.append(.practice(entry.id)) }
                        )
                    }
                case let .practice(entryID):
                    if let entry = entry(id: entryID) {
                        PracticeSessionView(
                            entry: entry,
                            rendering: rendering(for: entry),
                            session: contentRepository.practiceSession(for: entry.id)
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
                        let entry = contentRepository.createEntry(
                            spaceID: languageSpace.id,
                            title: title,
                            body: body,
                            source: .typedText
                        )
                        contentRevision += 1
                        presentedSheet = nil
                        navigationPath.append(.entryDetail(entry.id))
                    }
                case let .unavailable(action):
                    UnavailableCapabilityView(content: action.content)
                        .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                contentRepository.ensureSeeded(spaceID: languageSpace.id)
                contentRevision += 1
            }
        }
    }

    private var entries: [LearningEntry] {
        _ = contentRevision
        return contentRepository.entries(for: languageSpace.id)
    }

    private func entry(id: String) -> LearningEntry? {
        entries.first { $0.id == id }
    }

    private func rendering(for entry: LearningEntry) -> LearningRendering? {
        contentRepository.rendering(for: entry.id)
    }

    private func capability(kind: SettingsCapability.Kind) -> SettingsCapability? {
        contentRepository
            .settingsCapabilities(for: languageSpace.id)
            .first { $0.kind == kind }
    }

    private func showEntryDetail(_ entry: LearningEntry) {
        contentRepository.selectEntry(id: entry.id, spaceID: languageSpace.id)
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
