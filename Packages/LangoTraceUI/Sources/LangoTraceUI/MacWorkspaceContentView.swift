import LangoTraceCore
import LangoTraceData
import SwiftUI

struct MacWorkspaceContentView: View {
    let selectedSection: MacWorkspaceSection
    let route: MacWorkspaceRoute
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let selectedEntryID: String?
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
    let onShowEntry: (LearningEntry) -> Void
    let onRoute: (MacWorkspaceRoute) -> Void

    var body: some View {
        sectionContent
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch route {
        case .overview:
            overviewContent
        case let .entryDetail(entryID):
            entryDetail(entryID: entryID)
        case .reading:
            ReadingLibraryView(
                platform: .mac,
                store: readingLibraryStore,
                explanationAction: readingExplanationAction,
                ttsAction: readingTTSAction,
                cacheStorage: readingCacheStorage
            )
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
        case let .settings(kind):
            settingDetail(kind: kind)
        case .languageSpaceManagement:
            languageSpaceManagement
        case let .unavailable(kind):
            macUnavailableView(kind: kind)
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        switch selectedSection {
        case .today:
            todayContent
        case .entries:
            entriesContent
        case .reading:
            ReadingLibraryView(
                platform: .mac,
                store: readingLibraryStore,
                explanationAction: readingExplanationAction,
                ttsAction: readingTTSAction,
                cacheStorage: readingCacheStorage
            )
        case .practice:
            practiceContent
        case .memory:
            memoryContent
        case .importExport:
            macUnavailableView(kind: "import-export")
        case .settings:
            settingsContent
        }
    }

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedEntry {
                entryDetailView(for: selectedEntry)
            } else {
                LocalizedCompactPanel(
                    titleKey: "mac.today.empty.title",
                    textKey: "mac.today.empty.body",
                    systemImage: "square.and.pencil"
                )
            }
            HStack(alignment: .top, spacing: 14) {
                CapabilityStatusRow(
                    localizedTitleKey: "mac.searchFilter.title",
                    localizedSummaryKey: "mac.searchFilter.summary",
                    status: .unavailable,
                    systemImage: "magnifyingglass",
                    action: { onRoute(.unavailable("search")) }
                )
                CapabilityStatusRow(
                    localizedTitleKey: "mac.bulkImport.title",
                    localizedSummaryKey: "mac.bulkImport.summary",
                    status: .unavailable,
                    systemImage: "tray.and.arrow.down",
                    action: { onRoute(.unavailable("import-export")) }
                )
            }
        }
    }

    private var entriesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "mac.entries.library.title", subtitleKey: "mac.entries.library.subtitle")
            ForEach(entries) { entry in
                EntryTimelineRow(
                    entry: entry,
                    targetLanguage: languageSpace.targetLanguage,
                    isSelected: entry.id == selectedEntryID,
                    action: { onShowEntry(entry) }
                )
            }
        }
    }

    private var practiceContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "mac.practice.section.title", subtitleKey: "mac.practice.section.subtitle")
            ForEach(entries) { entry in
                let items = contentStore.practiceItems(for: entry)
                if items.isEmpty {
                    CapabilityStatusRow(
                        title: entry.title,
                        localizedSummaryKey: "mac.practice.noRendering.summary",
                        status: .unavailable,
                        systemImage: "waveform",
                        action: nil
                    )
                } else {
                    practiceItems(items, for: entry)
                }
            }
        }
    }

    private func practiceItems(_ items: [PracticeItem], for entry: LearningEntry) -> some View {
        ForEach(items) { item in
            CapabilityStatusRow(
                title: item.title,
                summary: "\(entry.title) · \(item.summary)",
                status: .ready,
                systemImage: "waveform",
                action: { onRoute(.practiceSentenceList(entry.id)) }
            )
        }
    }

    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "mac.memory.section.title", subtitleKey: "mac.memory.section.subtitle")
            MemoryLayerSummaryView(memoryItems: memoryItems)
            ForEach(memoryItems) { item in
                CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
            }
            UnavailableCapabilityView(content: .vectorIndex)
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "mac.settings.section.title", subtitleKey: "mac.settings.section.subtitle")
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
    }

    private var languageSpaceManagement: some View {
        LanguageSpaceManagementView(
            spaces: languageSpaces,
            currentSpaceID: languageSpace.id,
            onAdd: onAddLanguageSpace,
            onSelect: onSelectLanguageSpace,
            onUpdate: onUpdateLanguageSpace,
            onDelete: onDeleteLanguageSpace
        )
    }

    @ViewBuilder
    private func entryDetail(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            entryDetailView(for: entry)
        } else {
            LocalizedCompactPanel(
                titleKey: "mac.entryMissing.title",
                textKey: "mac.entryMissing.body",
                systemImage: "exclamationmark.circle"
            )
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
    }

    @ViewBuilder
    private func practiceSentenceList(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            PracticeSentenceListView(
                entry: entry,
                rendering: contentStore.rendering(for: entry),
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
                onPracticeSentence: { onRoute(.practiceSentence($0)) }
            )
        } else {
            LocalizedCompactPanel(
                titleKey: "mac.practiceUnavailable.title",
                textKey: "mac.practiceUnavailable.body",
                systemImage: "waveform"
            )
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
                presentation: .embeddedInExistingScroll,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                onAppearancePreferenceChange: onAppearancePreferenceChange
            )
        } else {
            LocalizedCompactPanel(
                titleKey: "mac.settingMissing.title",
                textKey: "mac.settingMissing.body",
                systemImage: "gearshape"
            )
        }
    }

    private func macUnavailableView(kind: String) -> some View {
        let content = MacUnavailableContent(kind: kind)
        return UnavailableCapabilityView(content: content.content)
    }

    private var sentenceAudioStates: [String: SentenceAudioPresentationState] {
        contentStore.sentenceAudioPlaybackStates
    }
}
