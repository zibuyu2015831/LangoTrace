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
    let contentStore: LearningContentStore
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
            case .languageSpaceSummary:
                languageSpaceSummaryPage
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
                rendering: contentStore.rendering(for: entry),
                practiceItems: contentStore.practiceItems(for: entry),
                onGenerateLocalPreview: { contentStore.generateLocalPreview(for: entry) },
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
                rendering: contentStore.rendering(for: entry),
                session: contentStore.practiceSession(for: entry)
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

    private var languageSpaceSummaryPage: some View {
        LanguageSpaceSummaryView(languageSpace: languageSpace)
            .frame(maxWidth: 820, alignment: .leading)
    }
}
