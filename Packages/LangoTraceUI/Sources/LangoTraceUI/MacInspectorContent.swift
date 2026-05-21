import LangoTraceData
import SwiftUI

struct MacInspectorContent: View {
    let route: MacWorkspaceRoute
    let selectedSection: MacWorkspaceSection
    let entries: [LearningEntry]
    let settingsCapabilities: [SettingsCapability]
    let contentStore: LearningContentStore

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case let .entryDetail(entryID):
            if let entry = entries.first(where: { $0.id == entryID }) {
                TextPanel(
                    title: localizedString("mac.inspector.entryMetadata.title"),
                    text: "\(entry.displaySourceTitle) · \(entry.scene) · \(entry.practiceSummary)"
                )
                RequestPreviewCard(entry: entry, rendering: contentStore.rendering(for: entry))
                memoryCandidates(for: entry)
                LocalizedTextPanel(titleKey: "mac.inspector.privacy.title", textKey: "mac.inspector.privacy.body")
            } else {
                LocalizedTextPanel(titleKey: "mac.inspector.noEntry.title", textKey: "mac.inspector.noEntry.body")
            }
        case .practice:
            LocalizedTextPanel(
                titleKey: "mac.inspector.practiceStatus.title",
                textKey: "mac.inspector.practiceStatus.body"
            )
            LocalizedTextPanel(
                titleKey: "mac.inspector.nextCapability.title",
                textKey: "mac.inspector.nextCapability.body"
            )
        case let .settings(kind):
            if let capability = settingsCapabilities.first(where: { $0.kind == kind }) {
                if kind == .interfaceLanguage {
                    LocalizedTextPanel(
                        titleKey: capability.kind.localizedTitleKey,
                        textKey: "settings.interfaceLanguage.selectionFootnote"
                    )
                } else {
                    let localizationKeys = settingsCapabilityDetailLocalizationKeys(for: capability.kind)

                    LocalizedTextPanel(
                        titleKey: capability.kind.localizedTitleKey,
                        textKey: localizationKeys.detail
                    )
                    LocalizedTextPanel(
                        titleKey: settingsNextRequirementTitleKey,
                        textKey: localizationKeys.nextRequirement
                    )
                }
            }
        case .unavailable:
            LocalizedTextPanel(
                titleKey: "capabilityStatus.unavailable",
                textKey: "mac.inspector.unavailable.body"
            )
        case .languageSpaceManagement:
            LocalizedTextPanel(
                titleKey: "settings.languageSpace.title",
                textKey: "settings.languageSpace.detail"
            )
            LocalizedTextPanel(
                titleKey: settingsNextRequirementTitleKey,
                textKey: "settings.languageSpace.nextRequirement"
            )
        case .overview:
            overviewInspector
        }
    }

    private func memoryCandidates(for entry: LearningEntry) -> some View {
        let candidates = contentStore.memoryItems(for: entry)

        return VStack(alignment: .leading, spacing: 10) {
            localizedText("mac.inspector.memoryCandidates")
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)

            if candidates.isEmpty {
                LocalizedTextPanel(
                    titleKey: "mac.inspector.noMemory.title",
                    textKey: "mac.inspector.noMemory.body"
                )
            } else {
                ForEach(candidates) { item in
                    CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
                }
            }
        }
    }

    @ViewBuilder
    private var overviewInspector: some View {
        switch selectedSection {
        case .today:
            LocalizedTextPanel(titleKey: "mac.inspector.today.title", textKey: "mac.inspector.today.body")
        case .entries:
            LocalizedTextPanel(titleKey: "mac.inspector.entries.title", textKey: "mac.inspector.entries.body")
        case .practice:
            LocalizedTextPanel(titleKey: "mac.inspector.practice.title", textKey: "mac.inspector.practice.body")
        case .memory:
            LocalizedTextPanel(titleKey: "mac.inspector.memory.title", textKey: "mac.inspector.memory.body")
        case .importExport:
            LocalizedTextPanel(titleKey: "mac.inspector.importExport.title", textKey: "mac.inspector.importExport.body")
        case .settings:
            LocalizedTextPanel(titleKey: "mac.inspector.settings.title", textKey: "mac.inspector.settings.body")
        }
    }
}
