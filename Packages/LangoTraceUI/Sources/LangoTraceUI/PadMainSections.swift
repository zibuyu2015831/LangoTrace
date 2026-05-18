import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PadSidebarView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let filteredEntries: [LearningEntry]
    let memoryItems: [MemoryItem]
    let selectedEntry: LearningEntry?
    let activeFilter: PadFilter
    let route: PadWorkspaceRoute
    let onSelectEntry: (LearningEntry) -> Void
    let onSelectFilter: (PadFilter) -> Void
    let onRoute: (PadWorkspaceRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SidebarSectionTitle("pad.sidebar.timeline")
            VStack(spacing: 10) {
                ForEach(filteredEntries) { entry in
                    EntryTimelineRow(
                        entry: entry,
                        targetLanguage: languageSpace.targetLanguage,
                        isSelected: entry.id == selectedEntry?.id
                    ) {
                        onSelectEntry(entry)
                    }
                }
            }

            SidebarSectionTitle("pad.sidebar.filters")
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PadFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        titleKey: filter.titleKey,
                        count: "\(entries.count { filter.includes(entry: $0, memoryItems: memoryItems) })",
                        active: activeFilter == filter
                    ) {
                        onSelectFilter(filter)
                    }
                }
            }

            SidebarSectionTitle("pad.sidebar.pages")
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
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
                PadRouteButton(titleKey: "tab.settings", systemImage: "gearshape", active: route == .settingsList) {
                    onRoute(.settingsList)
                }
            }

            Spacer()

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
}

struct PadWorkspaceContentView: View {
    let route: PadWorkspaceRoute
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let selectedEntry: LearningEntry?
    let selectedRendering: LearningRendering?
    let memoryItems: [MemoryItem]
    let settingsCapabilities: [SettingsCapability]
    let contentRepository: InMemoryLearningContentRepository
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onRoute: (PadWorkspaceRoute) -> Void

    var body: some View {
        Group {
            switch route {
            case .workspace:
                workspaceOverview
            case let .entryDetail(entryID):
                entryDetail(entryID: entryID)
            case let .practice(entryID):
                practice(entryID: entryID)
            case let .settings(kind):
                settingDetail(kind: kind)
            case .settingsList:
                settingsList
            case .memory:
                memoryPage
            case .importExport:
                importExportPage
            case .languageSpaceUnavailable:
                languageSpaceUnavailablePage
            }
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    private var workspaceOverview: some View {
        ScrollView {
            if let selectedEntry {
                VStack(alignment: .leading, spacing: 18) {
                    EntryDetailHeader(
                        entry: selectedEntry,
                        targetLanguage: languageSpace.targetLanguage,
                        rendering: selectedRendering
                    )
                    HStack(alignment: .top, spacing: 14) {
                        TextPanel(title: localizedString("entry.nativeRecord.title"), text: selectedEntry.body)
                        TextPanel(
                            title: localizedString("entry.targetLanguage.title"),
                            text: selectedRendering?.targetText ?? localizedString("entry.rendering.pending")
                        )
                    }
                    AudioPanel()
                    sentenceList(for: selectedEntry)
                }
                .padding(26)
                .frame(maxWidth: 820, alignment: .leading)
            } else {
                EmptyWorkspacePanel()
                    .padding(26)
            }
        }
    }

    private func sentenceList(for entry: LearningEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaption(titleKey: "pad.sentences.title", subtitleKey: "pad.sentences.subtitle")
            ForEach(Array((selectedRendering?.sentences ?? []).enumerated()), id: \.element.id) { index, sentence in
                SentencePairView(
                    index: index + 1,
                    sentence: sentence,
                    onPractice: { onRoute(.practice(entry.id)) }
                )
            }
        }
    }

    @ViewBuilder
    private func entryDetail(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            EntryDetailView(
                languageSpace: languageSpace,
                entry: entry,
                rendering: contentRepository.rendering(for: entry.id),
                practiceItems: contentRepository.practiceItems(for: entry.id),
                onPractice: { onRoute(.practice(entry.id)) }
            )
        } else {
            EmptyWorkspacePanel()
                .padding(26)
        }
    }

    @ViewBuilder
    private func practice(entryID: String) -> some View {
        if let entry = entries.first(where: { $0.id == entryID }) {
            PracticeSessionView(
                entry: entry,
                rendering: contentRepository.rendering(for: entry.id),
                session: contentRepository.practiceSession(for: entry.id)
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
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
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
                        action: { onRoute(.settings(capability.kind)) }
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

    private var languageSpaceUnavailablePage: some View {
        ScrollView {
            UnavailableCapabilityView(content: .languageSpace)
                .frame(maxWidth: 820, alignment: .leading)
        }
    }
}

struct PadLearningPanelView: View {
    let selectedEntry: LearningEntry?
    let selectedRendering: LearningRendering?
    let memoryItems: [MemoryItem]
    let contentRepository: InMemoryLearningContentRepository
    let onRoute: (PadWorkspaceRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(titleKey: "pad.learningPanel.title", subtitleKey: "pad.learningPanel.subtitle")
                if let selectedEntry {
                    selectedEntryContent(selectedEntry)
                } else {
                    LocalizedTextPanel(
                        titleKey: "pad.learningPanel.empty.title",
                        textKey: "pad.learningPanel.empty.body"
                    )
                }
            }
            .padding(22)
        }
        .frame(
            minWidth: 300,
            idealWidth: LangoTraceDesign.Density.padInspectorWidth,
            maxWidth: 360,
            alignment: .topLeading
        )
        .background(LangoTraceDesign.ColorToken.surfaceInspector.opacity(0.58))
    }

    private func selectedEntryContent(_ entry: LearningEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TextPanel(
                title: localizedString("pad.currentSentence.title"),
                text: selectedRendering?.sentences.first?.note ?? localizedString("pad.currentSentence.pending")
            )
            TextPanel(
                title: localizedString("pad.memoryExtraction.title"),
                text: memorySummary(for: entry)
            )
            CapabilityStatusRow(
                localizedTitleKey: "pad.practiceEntry.title",
                summary: practiceSummary(for: entry),
                status: contentRepository.practiceItems(for: entry.id).isEmpty ? .unavailable : .mockOnly,
                systemImage: "waveform",
                action: contentRepository.practiceItems(for: entry.id).isEmpty ? nil : { onRoute(.practice(entry.id)) }
            )
            CapabilityStatusRow(
                localizedTitleKey: "pad.spaceSettings.title",
                localizedSummaryKey: "pad.spaceSettings.summary",
                status: .mockOnly,
                systemImage: "gearshape",
                action: { onRoute(.settingsList) }
            )
            RequestPreviewCard(entry: entry, rendering: selectedRendering)
        }
    }

    private func memorySummary(for entry: LearningEntry) -> String {
        let extracted = memoryItems
            .filter { $0.entryID == entry.id }
            .map(\.text)

        guard !extracted.isEmpty else {
            return localizedString("pad.memory.empty.summary")
        }

        return extracted.joined(separator: ", ")
    }

    private func practiceSummary(for entry: LearningEntry) -> String {
        let summaries = contentRepository.practiceItems(for: entry.id).map(\.summary)

        guard !summaries.isEmpty else {
            return localizedString("pad.practice.empty.summary")
        }

        return summaries.joined(separator: " · ")
    }
}
