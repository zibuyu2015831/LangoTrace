import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PadLearningPanelView: View {
    let route: PadWorkspaceRoute
    let selectedEntry: LearningEntry?
    let selectedRendering: LearningRendering?
    let memoryItems: [MemoryItem]
    let contentStore: LearningContentStore
    let onRoute: (PadWorkspaceRoute) -> Void

    private let contentPadding = EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 32)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                panelContent
            }
            .padding(contentPadding)
        }
        .frame(
            minWidth: 300,
            idealWidth: LangoTraceDesign.Density.padInspectorWidth,
            maxWidth: 360,
            alignment: .topLeading
        )
        .background(LangoTraceDesign.ColorToken.surfaceInspector.opacity(0.58))
    }

    @ViewBuilder
    private var panelContent: some View {
        switch route {
        case .workspace, .entryDetail, .practiceSentenceList, .practiceSentence:
            SectionCaption(titleKey: "pad.learningPanel.title", subtitleKey: "pad.learningPanel.subtitle")
            if let selectedEntry {
                entryLearningContent(selectedEntry)
            } else {
                LocalizedTextPanel(
                    titleKey: "pad.learningPanel.empty.title",
                    textKey: "pad.learningPanel.empty.body"
                )
            }
        case .settingsList, .settings:
            settingsContextContent
        case .memory:
            routeContextContent(
                titleKey: "pad.learningPanel.memory.title",
                subtitleKey: "pad.learningPanel.memory.subtitle",
                panelTitleKey: "pad.learningPanel.memory.panel.title",
                panelTextKey: "pad.learningPanel.memory.panel.body",
                systemImage: "archivebox"
            )
        case .importExport:
            routeContextContent(
                titleKey: "pad.learningPanel.importExport.title",
                subtitleKey: "pad.learningPanel.importExport.subtitle",
                panelTitleKey: "pad.learningPanel.importExport.panel.title",
                panelTextKey: "pad.learningPanel.importExport.panel.body",
                systemImage: "tray.and.arrow.down"
            )
        case .languageSpaceManagement:
            routeContextContent(
                titleKey: "pad.learningPanel.languageSpace.title",
                subtitleKey: "pad.learningPanel.languageSpace.subtitle",
                panelTitleKey: "pad.learningPanel.languageSpace.panel.title",
                panelTextKey: "pad.learningPanel.languageSpace.panel.body",
                systemImage: "globe.asia.australia"
            )
        }
    }

    private var settingsContextContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(
                titleKey: "pad.learningPanel.settings.title",
                subtitleKey: "pad.learningPanel.settings.subtitle"
            )
            CapabilityStatusRow(
                localizedTitleKey: SettingsCapability.Kind.aiProvider.localizedTitleKey,
                localizedSummaryKey: "pad.learningPanel.settings.aiProvider.summary",
                status: .mockOnly,
                systemImage: SettingsCapability.Kind.aiProvider.systemImage,
                action: { onRoute(.settings(.aiProvider)) }
            )
            CapabilityStatusRow(
                localizedTitleKey: SettingsCapability.Kind.sync.localizedTitleKey,
                localizedSummaryKey: "pad.learningPanel.settings.sync.summary",
                status: .unavailable,
                systemImage: SettingsCapability.Kind.sync.systemImage,
                action: { onRoute(.settings(.sync)) }
            )
            LocalizedTextPanel(
                titleKey: "pad.learningPanel.settings.privacy.title",
                textKey: "pad.learningPanel.settings.privacy.body"
            )
        }
    }

    private func routeContextContent(
        titleKey: String,
        subtitleKey: String,
        panelTitleKey: String,
        panelTextKey: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(titleKey: titleKey, subtitleKey: subtitleKey)
            LocalizedCompactPanel(
                titleKey: panelTitleKey,
                textKey: panelTextKey,
                systemImage: systemImage
            )
        }
    }

    private func entryLearningContent(_ entry: LearningEntry) -> some View {
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
                status: contentStore.practiceItems(for: entry).isEmpty ? .unavailable : .mockOnly,
                systemImage: "waveform",
                action: contentStore.practiceItems(for: entry).isEmpty ? nil : { onRoute(.practiceSentenceList(entry.id)) }
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
        let summaries = contentStore.practiceItems(for: entry).map(\.summary)

        guard !summaries.isEmpty else {
            return localizedString("pad.practice.empty.summary")
        }

        return summaries.joined(separator: " · ")
    }
}
