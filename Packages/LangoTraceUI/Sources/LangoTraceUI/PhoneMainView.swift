import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview
    let languageSpaces: [LanguageSpace]
    @ObservedObject var contentStore: LearningContentStore
    let practiceActions: PracticeActions
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    let onSelectLanguageSpace: (String) -> Void
    let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    let onDeleteLanguageSpace: (String) -> Void
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void

    @State private var selectedTab: PhoneRootTab = .entries
    @State private var navigationPath: [PhoneRoute] = []
    @State private var presentedSheet: PhoneSheet?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                PhoneRecordWorkspaceView(
                    languageSpace: languageSpace,
                    entries: entries,
                    renderingForEntry: rendering(for:),
                    onNewEntry: { presentedSheet = .entryEditor },
                    onPhotoWriting: { presentedSheet = .photoWritingPreview },
                    onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                    onSettingsAction: { navigationPath.append(.settingsList) },
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
                    renderingForEntry: rendering(for:),
                    onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                    onSettingsAction: { navigationPath.append(.settingsList) },
                    onPractice: { entry in navigationPath.append(.practiceSentenceList(entry.id)) }
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
                    onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                    onSettingsAction: { navigationPath.append(.settingsList) }
                )
                .tabItem {
                    Label {
                        localizedText(PhoneRootTab.memory.localizedTitleKey)
                    } icon: {
                        Image(systemName: "archivebox")
                    }
                }
                .tag(PhoneRootTab.memory)
            }
            .phoneTabBarBackground()
            .navigationDestination(for: PhoneRoute.self) { route in
                switch route {
                case let .entryDetail(entryID):
                    if let entry = entry(id: entryID) {
                        EntryDetailStoreView(
                            languageSpace: languageSpace,
                            entryID: entry.id,
                            contentStore: contentStore,
                            titlePresentation: .objectNavigationTitle,
                            onPracticeSentence: { seed in navigationPath.append(.practiceSentence(seed)) }
                        )
                    }
                case let .practiceSentenceList(entryID):
                    if let entry = entry(id: entryID) {
                        PracticeSentenceListView(
                            entry: entry,
                            rendering: rendering(for: entry),
                            languageSpace: languageSpace,
                            sentenceAudioPlaybackStates: sentenceAudioStates,
                            onListenSentence: { rendering, sentence, index in
                                Task {
                                    await contentStore.handleSentenceAudioTap(
                                        rendering: rendering,
                                        sentence: sentence,
                                        sentenceIndex: index,
                                        languageSpace: languageSpace
                                    )
                                }
                            },
                            onPracticeSentence: { seed in navigationPath.append(.practiceSentence(seed)) }
                        )
                    }
                case let .practiceSentence(seed):
                    PracticeSessionView(
                        languageSpaceID: languageSpace.id,
                        routeSeed: seed,
                        actions: practiceActions,
                        onPlayDemo: {
                            await contentStore.handlePracticeDemoTap(routeSeed: seed, languageSpace: languageSpace)
                        },
                        onStopDemo: {
                            await contentStore.stopSentenceAudioPlayback()
                        },
                        onNavigateSentence: { nextSeed in
                            replaceCurrentRoute(with: .practiceSentence(nextSeed))
                        }
                    )
                    .id(seed.practiceRouteIdentity)
                case .settings(.languageSpace):
                    LanguageSpaceManagementView(
                        spaces: languageSpaces,
                        currentSpaceID: languageSpace.id,
                        onAdd: onAddLanguageSpace,
                        onSelect: onSelectLanguageSpace,
                        onUpdate: onUpdateLanguageSpace,
                        onDelete: onDeleteLanguageSpace
                    )
                case let .settings(kind):
                    if let capability = capability(kind: kind) {
                        SettingsCapabilityDetailView(
                            languageSpace: languageSpace,
                            capability: capability,
                            interfaceLanguagePreference: interfaceLanguagePreference,
                            appearancePreference: appearancePreference,
                            onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                            onAppearancePreferenceChange: onAppearancePreferenceChange
                        )
                    }
                case .settingsList:
                    SettingsView(
                        languageSpace: languageSpace,
                        capabilities: contentStore.settingsCapabilities,
                        onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                        onSettingsAction: nil,
                        onSelectCapability: { kind in navigationPath.append(.settings(kind)) }
                    )
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .entryEditor:
                    EntryEditorView(languageSpace: languageSpace) { title, body in
                        guard let entry = try? contentStore.createEntry(
                            title: title,
                            body: body,
                            source: .typedText
                        ) else { return }
                        presentedSheet = nil
                        navigationPath.append(.entryDetail(entry.id))
                    }
                case .photoWritingPreview:
                    PhotoWritingPreviewView(languageSpace: languageSpace) {
                        guard let entry = try? contentStore.createMockPhotoWritingEntry() else { return }
                        presentedSheet = nil
                        navigationPath.append(.entryDetail(entry.id))
                    } onDismiss: {
                        presentedSheet = nil
                    }
                case let .unavailable(action):
                    UnavailableCapabilityView(content: action.content) {
                        presentedSheet = nil
                    }
                    .presentationDetents([.medium, .large])
                case .languageSpaceSwitcher:
                    NavigationStack {
                        LanguageSpaceSwitcherSheet(
                            spaces: languageSpaces,
                            currentSpaceID: languageSpace.id,
                            onSelect: { id in
                                onSelectLanguageSpace(id)
                            },
                            onAdd: { input in
                                onAddLanguageSpace(input)
                            },
                            onManage: {
                                presentedSheet = nil
                                navigationPath.append(.settings(.languageSpace))
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button {
                                    presentedSheet = nil
                                } label: {
                                    localizedText("common.close")
                                }
                            }
                        }
                    }
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

    private var sentenceAudioStates: [String: SentenceAudioPresentationState] {
        contentStore.sentenceAudioPlaybackStates
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

    private func replaceCurrentRoute(with route: PhoneRoute) {
        guard !navigationPath.isEmpty else {
            navigationPath.append(route)
            return
        }
        navigationPath[navigationPath.count - 1] = route
    }
}

private enum PhoneRoute: Hashable {
    case entryDetail(String)
    case practiceSentenceList(String)
    case practiceSentence(PracticeSessionRouteSeed)
    case settings(SettingsCapability.Kind)
    case settingsList
}

private enum PhoneSheet: Identifiable {
    case entryEditor
    case photoWritingPreview
    case unavailable(PhoneUnavailableAction)
    case languageSpaceSwitcher

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        case .photoWritingPreview:
            "photo-writing-preview"
        case let .unavailable(action):
            "unavailable-\(action.rawValue)"
        case .languageSpaceSwitcher:
            "language-space-switcher"
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
