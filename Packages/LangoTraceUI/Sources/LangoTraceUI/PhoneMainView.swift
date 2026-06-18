import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview
    let languageSpaces: [LanguageSpace]
    @ObservedObject var contentStore: LearningContentStore
    @ObservedObject var readingLibraryStore: ReadingLibraryStore
    let readingExplanationAction: ReadingExplanationAction
    let readingTTSAction: ReadingTTSAction
    let readingCacheStorage: (any ExplanationCacheStorage)?
    let practiceActions: PracticeActions
    let photoWritingActions: PhotoWritingActions
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    let onSelectLanguageSpace: (String) -> Void
    let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    let onDeleteLanguageSpace: (String) -> Void
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void

    @State private var navModel = PhoneTabNavigationModel()
    @State private var presentedSheet: PhoneSheet?

    var body: some View {
        @Bindable var nav = navModel
        TabView(selection: $nav.selectedTab) {
            NavigationStack(path: $nav.entriesPath) {
                PhoneRecordWorkspaceView(
                    languageSpace: languageSpace,
                    entries: entries,
                    practiceReadiness: contentStore.practiceReadiness,
                    renderingForEntry: rendering(for:),
                    onNewEntry: { presentedSheet = .entryEditor },
                    onPhotoWriting: { presentedSheet = .photoWriting },
                    onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                    onSettingsAction: { navModel.push(.settingsList, on: .entries) },
                    onSelectEntry: showEntryDetail
                )
                .phoneNavigationDestinations(for: .entries, context: self)
                .onAppear { contentStore.ensureSeeded() }
            }
            .tabItem {
                Label {
                    localizedText(PhoneRootTab.entries.localizedTitleKey)
                } icon: {
                    Image(systemName: "square.and.pencil")
                }
            }
            .tag(PhoneRootTab.entries)

            NavigationStack(path: $nav.readingPath) {
                ReadingLibraryView(
                    platform: .phone,
                    store: readingLibraryStore,
                    explanationAction: readingExplanationAction,
                    ttsAction: readingTTSAction,
                    cacheStorage: readingCacheStorage,
                    onOpenPhoneDocument: { documentID in
                        navModel.push(.readingDocument(documentID), on: .reading)
                    }
                )
                .phoneNavigationDestinations(for: .reading, context: self)
            }
            .tabItem {
                Label {
                    localizedText(PhoneRootTab.reading.localizedTitleKey)
                } icon: {
                    Image(systemName: "book.pages")
                }
            }
            .tag(PhoneRootTab.reading)

            NavigationStack(path: $nav.practicePath) {
                PracticeView(
                    languageSpace: languageSpace,
                    entries: entries,
                    contentStore: contentStore,
                    renderingForEntry: rendering(for:),
                    onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                    onSettingsAction: { navModel.push(.settingsList, on: .practice) },
                    onPractice: { entry in navModel.push(.practiceSentenceList(entry.id), on: .practice) }
                )
                .phoneNavigationDestinations(for: .practice, context: self)
            }
            .tabItem {
                Label {
                    localizedText(PhoneRootTab.practice.localizedTitleKey)
                } icon: {
                    Image(systemName: "waveform")
                }
            }
            .tag(PhoneRootTab.practice)

            NavigationStack(path: $nav.memoryPath) {
                MemoryView(
                    languageSpace: languageSpace,
                    memoryItems: contentStore.memoryItems,
                    onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                    onSettingsAction: { navModel.push(.settingsList, on: .memory) }
                )
                .phoneNavigationDestinations(for: .memory, context: self)
            }
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
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .entryEditor:
                EntryEditorView(languageSpace: languageSpace) { title, body in
                    let entry = try contentStore.createEntry(
                        title: title,
                        body: body,
                        source: .typedText
                    )
                    presentedSheet = nil
                    navModel.push(.entryDetail(entry.id), on: .entries)
                }
            case .photoWriting:
                PhotoWritingView(languageSpace: languageSpace) { body, imageData in
                    let coordinator = PhotoWritingSaveCoordinator(
                        createEntry: { title, body, source in
                            try contentStore.createEntry(title: title, body: body, source: source)
                        },
                        deleteEntry: { entryID in
                            try contentStore.deleteEntry(id: entryID)
                        },
                        importPhoto: photoWritingActions.importPhoto
                    )
                    let entry = try coordinator.save(body: body, imageData: imageData, spaceID: languageSpace.id)
                    presentedSheet = nil
                    navModel.push(.entryDetail(entry.id), on: .entries)
                } onDismiss: {
                    presentedSheet = nil
                }
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
                            let currentTab = navModel.selectedTab
                            presentedSheet = nil
                            navModel.push(.settings(.languageSpace), on: currentTab)
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
        navModel.push(.entryDetail(entry.id), on: .entries)
    }

    /// Returns the destination view for a given route, capturing the active tab
    /// so nested navigation closures push/replace on the correct per-tab stack.
    @ViewBuilder
    fileprivate func destination(for route: PhoneRoute, activeTab tab: PhoneRootTab) -> some View {
        switch route {
        case let .entryDetail(entryID):
            if let entry = entry(id: entryID) {
                EntryDetailStoreView(
                    languageSpace: languageSpace,
                    entryID: entry.id,
                    contentStore: contentStore,
                    titlePresentation: .objectNavigationTitle,
                    onPracticeSentence: { seed in navModel.push(.practiceSentence(seed), on: tab) },
                    onOpenReading: { entryID in navModel.push(.bilingualReading(entryID), on: tab) }
                )
            }
        case let .bilingualReading(entryID):
            if let entry = entry(id: entryID) {
                EntryReadingStoreView(
                    languageSpace: languageSpace,
                    entryID: entry.id,
                    contentStore: contentStore
                )
            }
        case let .practiceSentenceList(entryID):
            if let entry = entry(id: entryID) {
                PracticeSentenceListView(
                    entry: entry,
                    rendering: rendering(for: entry),
                    languageSpace: languageSpace,
                    sentenceAudioPlaybackStates: sentenceAudioStates,
                    practiceActions: practiceActions,
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
                    onPracticeSentence: { seed in navModel.push(.practiceSentence(seed), on: tab) }
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
                    navModel.replaceCurrentRoute(with: .practiceSentence(nextSeed), on: tab)
                }
            )
            .id(seed.practiceRouteIdentity)
        case let .readingDocument(documentID):
            ReadingDocumentDetailView(
                platform: .phone,
                documentID: documentID,
                store: readingLibraryStore,
                explanationAction: readingExplanationAction,
                ttsAction: readingTTSAction
            )
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
                settingsStatus: contentStore.settingsStatus,
                interfaceLanguagePreference: interfaceLanguagePreference,
                appearancePreference: appearancePreference,
                onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher },
                onSettingsAction: nil,
                onSelectCapability: { kind in navModel.push(.settings(kind), on: tab) },
                onAppearRefresh: { Task { await contentStore.refreshSettingsStatus() } }
            )
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

    func phoneNavigationDestinations(
        for tab: PhoneRootTab,
        context: PhoneMainView
    ) -> some View {
        navigationDestination(for: PhoneRoute.self) { route in
            context.destination(for: route, activeTab: tab)
        }
    }
}
