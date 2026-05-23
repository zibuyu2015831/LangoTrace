import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview
    let languageSpaces: [LanguageSpace]
    @ObservedObject var contentStore: LearningContentStore
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
                    onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                    onSettingsAction: { navigationPath.append(.settingsList) },
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
                        EntryDetailView(
                            languageSpace: languageSpace,
                            entry: entry,
                            rendering: rendering(for: entry),
                            practiceItems: contentStore.practiceItems(for: entry),
                            generationState: contentStore.generationState(for: entry),
                            sourceEntryIsStale: contentStore.sourceEntryIsStale(for: entry),
                            onGenerateLearningMaterial: {
                                Task {
                                    await contentStore.generateLearningMaterial(
                                        for: entry,
                                        languageSpace: languageSpace
                                    )
                                }
                            },
                            onCancelLearningMaterialGeneration: {
                                Task {
                                    await contentStore.cancelLearningMaterialGeneration(for: entry)
                                }
                            },
                            onUpdateEntryBody: { body in
                                try contentStore.updateEntryBody(entryID: entry.id, body: body)
                            },
                            onUpdateLearningText: { materialID, learningText in
                                Task {
                                    await contentStore.updateLearningText(
                                        materialID: materialID,
                                        entryID: entry.id,
                                        learningText: learningText
                                    )
                                }
                            },
                            onAnalyzeCurrentLearningText: {
                                Task {
                                    await contentStore.analyzeCurrentLearningText(
                                        for: entry,
                                        languageSpace: languageSpace
                                    )
                                }
                            },
                            sentenceAudioPlaybackState: { sentenceID in
                                contentStore.sentenceAudioPlaybackState(for: sentenceID)
                            },
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
                            onGenerateLocalPreview: { contentStore.generateLocalPreview(for: entry) },
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
