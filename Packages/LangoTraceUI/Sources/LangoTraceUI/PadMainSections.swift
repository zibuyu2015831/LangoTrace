import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PadSidebarView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let filteredEntries: [LearningEntry]
    let practiceReadiness: [String: Bool]
    let renderingForEntry: (LearningEntry) -> LearningRendering?
    let selectedEntry: LearningEntry?
    let activeFilter: EntryTimelineFilter
    let route: PadWorkspaceRoute
    let onSelectEntry: (LearningEntry) -> Void
    let onSelectFilter: (EntryTimelineFilter) -> Void
    let onRoute: (PadWorkspaceRoute) -> Void

    private var visibleFilters: [EntryTimelineFilter] {
        EntryTimelineFilter.allCases.filter { $0 != .settled }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Timeline, filters and routes can grow with real data, so they scroll;
            // the language-space footer stays pinned below the scroll region.
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SidebarSectionTitle("pad.sidebar.timeline")
                    LazyVStack(spacing: 10) {
                        ForEach(dayGroups) { group in
                            ForEach(group.entries) { entry in
                                EntryTimelineRow(
                                    entry: entry,
                                    rendering: renderingForEntry(entry),
                                    targetLanguage: languageSpace.targetLanguage,
                                    isSelected: entry.id == selectedEntry?.id
                                ) {
                                    onSelectEntry(entry)
                                }
                            }
                        }
                    }

                    SidebarSectionTitle("pad.sidebar.filters")
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleFilters, id: \.self) { filter in
                            FilterPill(
                                titleKey: filter.titleKey,
                                count: "\(entries.count { filter.includes(entry: $0, hasMaterialWithoutRecording: practiceReadiness[$0.id] == false, hasPhotoAttachment: false) })",
                                active: activeFilter == filter
                            ) {
                                onSelectFilter(filter)
                            }
                        }
                    }

                    SidebarSectionTitle("pad.sidebar.pages")
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        PadRouteButton(titleKey: "tab.reading", systemImage: "book.pages", active: route == .reading) {
                            onRoute(.reading)
                        }
                        PadRouteButton(titleKey: "tab.memory", systemImage: "archivebox", active: route == .memory) {
                            onRoute(.memory)
                        }
                        PadRouteButton(
                            titleKey: "mac.section.importExport",
                            systemImage: "tray.and.arrow.down",
                            active: route == .importExport
                        ) {
                            onRoute(.importExport)
                        }
                        PadRouteButton(
                            titleKey: "tab.settings",
                            systemImage: "gearshape",
                            active: route == .settingsList
                        ) {
                            onRoute(.settingsList)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            LanguageSpaceFooter(
                languageSpace: languageSpace,
                aiStatus: .notConfigured,
                syncStatus: .off,
                isCompact: false,
                onLanguageSpace: { onRoute(PadFooterAction.languageSpace.route) },
                onAIStatus: { onRoute(PadFooterAction.aiProvider.route) },
                onSyncStatus: { onRoute(PadFooterAction.sync.route) },
                onSettings: { onRoute(PadFooterAction.settings.route) }
            )
        }
        .padding(22)
        .frame(
            minWidth: 240,
            idealWidth: LangoTraceDesign.Density.padSidebarWidth,
            maxWidth: 300,
            alignment: .topLeading
        )
        .background(LangoTraceDesign.ColorToken.surfaceSidebar.opacity(0.72))
    }

    private var dayGroups: [EntryDayGroup] {
        groupEntriesByDay(filteredEntries)
    }
}

struct PadWorkspaceContentView: View {
    let route: PadWorkspaceRoute
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let selectedEntry: LearningEntry?
    let selectedRendering: LearningRendering?
    let memoryItems: [MemoryItem]
    let languageSpaces: [LanguageSpace]
    let settingsCapabilities: [SettingsCapability]
    @ObservedObject var contentStore: LearningContentStore
    @ObservedObject var readingLibraryStore: ReadingLibraryStore
    let readingExplanationAction: ReadingExplanationAction
    let readingTTSAction: ReadingTTSAction
    let readingCacheStorage: (any ExplanationCacheStorage)?
    let practiceActions: PracticeActions
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    let onSelectLanguageSpace: (String) -> Void
    let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    let onDeleteLanguageSpace: (String) -> Void
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void
    let onRoute: (PadWorkspaceRoute) -> Void

    var body: some View {
        Group {
            switch route {
            case .workspace:
                workspaceOverview
            case let .entryDetail(entryID):
                entryDetail(entryID: entryID)
            case let .practiceSentenceList(entryID):
                practiceSentenceList(entryID: entryID)
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
                        onRoute(.practiceSentence(nextSeed))
                    }
                )
                .id(seed.practiceRouteIdentity)
            case .reading:
                ReadingLibraryView(
                    platform: .pad,
                    store: readingLibraryStore,
                    explanationAction: readingExplanationAction,
                    ttsAction: readingTTSAction,
                    cacheStorage: readingCacheStorage
                )
            case let .settings(kind):
                settingDetail(kind: kind)
            case .settingsList:
                settingsList
            case .memory:
                memoryPage
            case .importExport:
                importExportPage
            case .languageSpaceManagement:
                languageSpaceManagementPage
            }
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    /// EntryDetailView owns its own ScrollView; this wrapper only handles layout.
    @ViewBuilder
    private var workspaceOverview: some View {
        if let selectedEntry {
            entryDetailView(for: selectedEntry)
        } else {
            EmptyWorkspacePanel()
                .padding(26)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sentenceList(for entry: LearningEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaption(titleKey: "pad.sentences.title", subtitleKey: "pad.sentences.subtitle")
            if let rendering = selectedRendering {
                ForEach(Array(rendering.sentences.enumerated()), id: \.element.id) { index, sentence in
                    SentencePairView(
                        index: index + 1,
                        sentence: sentence,
                        playbackState: contentStore.sentenceAudioPlaybackState(for: sentence.id),
                        onListen: {
                            Task {
                                await contentStore.handleSentenceAudioTap(
                                    rendering: rendering,
                                    sentence: sentence,
                                    sentenceIndex: index,
                                    languageSpace: languageSpace
                                )
                            }
                        },
                        onPractice: {
                            onRoute(
                                .practiceSentence(
                                    PracticeSessionRouteSeed(
                                        entry: entry,
                                        rendering: rendering,
                                        sentence: sentence,
                                        sentenceIndex: index,
                                        targetLanguageCode: languageSpace.targetLanguageCode,
                                        capturedAt: Date()
                                    )
                                )
                            )
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func entryDetail(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            entryDetailView(for: entry)
        } else {
            EmptyWorkspacePanel()
                .padding(26)
        }
    }

    private func entryDetailView(for entry: LearningEntry) -> some View {
        EntryDetailStoreView(
            languageSpace: languageSpace,
            entryID: entry.id,
            contentStore: contentStore,
            titlePresentation: .embeddedHeader,
            onPracticeSentence: { onRoute(.practiceSentence($0)) }
        )
        .padding(26)
        .frame(maxWidth: 820, alignment: .leading)
    }

    @ViewBuilder
    private func practiceSentenceList(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            PracticeSentenceListView(
                entry: entry,
                rendering: contentStore.rendering(for: entry),
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
                onPracticeSentence: { onRoute(.practiceSentence($0)) }
            )
        } else {
            EmptyWorkspacePanel()
                .padding(26)
        }
    }

    @ViewBuilder
    private func settingDetail(kind: SettingsCapability.Kind) -> some View {
        if let capability = settingsCapabilities.first(where: { $0.kind == kind }) {
            SettingsCapabilityDetailView(
                languageSpace: languageSpace,
                capability: capability,
                interfaceLanguagePreference: interfaceLanguagePreference,
                appearancePreference: appearancePreference,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                onAppearancePreferenceChange: onAppearancePreferenceChange
            )
        } else {
            EmptyWorkspacePanel()
                .padding(26)
        }
    }

    private var settingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(titleKey: "pad.settings.section.title", subtitleKey: "pad.settings.section.subtitle")
                ForEach(settingsCapabilities) { capability in
                    CapabilityStatusRow(
                        localizedTitleKey: capability.kind.localizedTitleKey,
                        localizedSummaryKey: settingsCapabilityDetailLocalizationKeys(for: capability.kind).summary,
                        status: capability.status,
                        systemImage: capability.kind.systemImage,
                        showsStatusBadge: false,
                        action: {
                            if capability.kind == .languageSpace {
                                onRoute(.languageSpaceManagement)
                            } else {
                                onRoute(.settings(capability.kind))
                            }
                        }
                    )
                }
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var memoryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(titleKey: "pad.memory.section.title", subtitleKey: "pad.memory.section.subtitle")
                MemoryLayerSummaryView(memoryItems: memoryItems)
                ForEach(memoryItems) { item in
                    CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
                }
                UnavailableCapabilityView(content: .vectorIndex)
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var importExportPage: some View {
        ScrollView {
            UnavailableCapabilityView(content: .importExport)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var languageSpaceManagementPage: some View {
        LanguageSpaceManagementView(
            spaces: languageSpaces,
            currentSpaceID: languageSpace.id,
            onAdd: onAddLanguageSpace,
            onSelect: onSelectLanguageSpace,
            onUpdate: onUpdateLanguageSpace,
            onDelete: onDeleteLanguageSpace
        )
        .frame(maxWidth: 820, alignment: .leading)
    }

    private var sentenceAudioStates: [String: SentenceAudioPresentationState] {
        contentStore.sentenceAudioPlaybackStates
    }
}
