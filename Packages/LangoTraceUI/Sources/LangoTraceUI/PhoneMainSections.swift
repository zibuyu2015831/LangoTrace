import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneRecordWorkspaceView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let renderingForEntry: (LearningEntry) -> LearningRendering?
    let onNewEntry: () -> Void
    let onPhotoWriting: () -> Void
    let onLanguageSpaceAction: () -> Void
    var onSettingsAction: (() -> Void)?
    let onSelectEntry: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            titleKey: "tab.entries",
            languageSpace: languageSpace,
            onLanguageSpaceAction: onLanguageSpaceAction,
            onSettingsAction: onSettingsAction
        ) {
            HeroActionCard(
                languageSpace: languageSpace,
                onNewEntry: onNewEntry,
                onPhotoWriting: onPhotoWriting
            )
            SectionHeader(titleKey: "phone.today.recent.title")
            if entries.isEmpty {
                EmptyEntryPanel(onNewEntry: onNewEntry)
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(entries) { entry in
                        EntryCard(
                            entry: entry,
                            targetLanguage: languageSpace.targetLanguage,
                            rendering: renderingForEntry(entry),
                            action: { onSelectEntry(entry) }
                        )
                    }
                }
            }
        }
    }
}

struct PracticeView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let contentStore: LearningContentStore
    let renderingForEntry: (LearningEntry) -> LearningRendering?
    let onLanguageSpaceAction: () -> Void
    var onSettingsAction: (() -> Void)?
    let onPractice: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            titleKey: "tab.practice",
            languageSpace: languageSpace,
            onLanguageSpaceAction: onLanguageSpaceAction,
            onSettingsAction: onSettingsAction
        ) {
            if entries.isEmpty {
                LocalizedCompactPanel(
                    titleKey: "phone.practice.empty.title",
                    textKey: "phone.practice.empty.body",
                    systemImage: "waveform"
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(entries) { entry in
                        PracticeEntryCard(
                            projection: projection(for: entry),
                            action: { onPractice(entry) }
                        )
                    }
                }
            }
        }
    }

    private func projection(for entry: LearningEntry) -> PracticeEntryCardProjection {
        let rendering = renderingForEntry(entry)
        let sentenceCount = rendering?.sentences.count ?? 0
        let targetPreview = rendering?.sentences.first?.targetText ?? entry.practiceSummary
        return PracticeEntryCardProjection(
            title: entry.title,
            targetPreview: targetPreview,
            sentenceCount: sentenceCount,
            completedCount: 0,
            problemCount: 0,
            statusText: entry.practiceSummary
        )
    }
}

struct MemoryView: View {
    let languageSpace: LanguageSpacePreview
    let memoryItems: [MemoryItem]
    let onLanguageSpaceAction: () -> Void
    var onSettingsAction: (() -> Void)?

    var body: some View {
        PhonePage(
            titleKey: "tab.memory",
            languageSpace: languageSpace,
            onLanguageSpaceAction: onLanguageSpaceAction,
            onSettingsAction: onSettingsAction
        ) {
            SectionHeader(titleKey: "phone.memory.personal.title", subtitleKey: "phone.memory.personal.subtitle")
            if memoryItems.isEmpty {
                LocalizedCompactPanel(
                    titleKey: "memory.empty.title",
                    textKey: "memory.empty.body",
                    systemImage: "bookmark"
                )
            } else {
                ForEach(memoryItems) { item in
                    CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
                }
            }
        }
    }
}

struct SettingsView: View {
    let languageSpace: LanguageSpacePreview
    let capabilities: [SettingsCapability]
    let onLanguageSpaceAction: () -> Void
    let onSettingsAction: (() -> Void)?
    let onSelectCapability: (SettingsCapability.Kind) -> Void

    var body: some View {
        PhonePage(
            titleKey: "tab.settings",
            languageSpace: languageSpace,
            onLanguageSpaceAction: onLanguageSpaceAction,
            onSettingsAction: onSettingsAction,
            showsContextHeader: false
        ) {
            ForEach(capabilities) { capability in
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    localizedSummaryKey: settingsCapabilityDetailLocalizationKeys(for: capability.kind).summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    showsStatusBadge: false,
                    action: { onSelectCapability(capability.kind) }
                )
            }
        }
    }
}

struct PhonePage<Content: View>: View {
    let titleKey: String
    let languageSpace: LanguageSpacePreview
    let onLanguageSpaceAction: () -> Void
    var onSettingsAction: (() -> Void)?
    var showsContextHeader = true
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if showsContextHeader {
                    PhoneContextHeader(
                        languageSpace: languageSpace,
                        onLanguageSpaceAction: onLanguageSpaceAction,
                        onSettingsAction: onSettingsAction
                    )
                }
                content
            }
            .padding(20)
            .padding(.bottom, 92)
        }
        .navigationTitle(localizedText(titleKey))
        .langoPageBackground()
    }
}
