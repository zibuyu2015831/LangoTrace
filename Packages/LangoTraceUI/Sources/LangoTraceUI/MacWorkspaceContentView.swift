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
    let settingsCapabilities: [SettingsCapability]
    let contentStore: LearningContentStore
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
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
        case let .practice(entryID):
            practice(entryID: entryID)
        case let .settings(kind):
            settingDetail(kind: kind)
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
                EntryDetailView(
                    languageSpace: languageSpace,
                    entry: selectedEntry,
                    rendering: selectedRendering,
                    practiceItems: contentStore.practiceItems(for: selectedEntry),
                    onGenerateLocalPreview: { contentStore.generateLocalPreview(for: selectedEntry) },
                    onPractice: { onRoute(.practice(selectedEntry.id)) }
                )
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
                status: .mockOnly,
                systemImage: "waveform",
                action: { onRoute(.practice(entry.id)) }
            )
        }
    }

    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "mac.memory.section.title", subtitleKey: "mac.memory.section.subtitle")
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
                    action: { onRoute(.settings(capability.kind)) }
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
            LocalizedCompactPanel(
                titleKey: "mac.entryMissing.title",
                textKey: "mac.entryMissing.body",
                systemImage: "exclamationmark.circle"
            )
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
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
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
}
