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

struct PracticeView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let contentStore: LearningContentStore
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
            SectionHeader(titleKey: "phone.practice.fromLife.title")
            if entries.isEmpty {
                LocalizedCompactPanel(
                    titleKey: "phone.practice.empty.title",
                    textKey: "phone.practice.empty.body",
                    systemImage: "waveform"
                )
            } else {
                if let firstPracticeEntry {
                    PracticeContinuePanel(entry: firstPracticeEntry, action: { onPractice(firstPracticeEntry) })
                }
                ForEach(entries) { entry in
                    let items = contentStore.practiceItems(for: entry)
                    if items.isEmpty {
                        PracticeTaskRow(
                            title: entry.title,
                            summary: localizedString("practice.empty.summary"),
                            systemImage: "text.badge.plus",
                            action: nil
                        )
                    } else {
                        ForEach(items) { item in
                            PracticeTaskRow(
                                title: item.title,
                                summary: "\(entry.title) · \(item.summary)",
                                systemImage: icon(for: item.kind),
                                action: { onPractice(entry) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var firstPracticeEntry: LearningEntry? {
        entries.first { !contentStore.practiceItems(for: $0).isEmpty }
    }

    private func icon(for kind: PracticeItem.Kind) -> String {
        switch kind {
        case .listening:
            "ear"
        case .shadowing:
            "waveform"
        case .dictation:
            "character.cursor.ibeam"
        case .backTranslation:
            "arrow.left.arrow.right"
        }
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
            onSettingsAction: onSettingsAction
        ) {
            ForEach(capabilities) { capability in
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    localizedSummaryKey: settingsCapabilityDetailLocalizationKeys(for: capability.kind).summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
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
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhoneContextHeader(
                    languageSpace: languageSpace,
                    onLanguageSpaceAction: onLanguageSpaceAction,
                    onSettingsAction: onSettingsAction
                )
                content
            }
            .padding(20)
            .padding(.bottom, 92)
        }
        .navigationTitle(localizedText(titleKey))
        .langoPageBackground()
    }
}
