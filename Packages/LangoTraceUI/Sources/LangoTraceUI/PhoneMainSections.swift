import LangoTraceCore
import LangoTraceData
import SwiftUI

struct TodayView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let renderingForEntry: (LearningEntry) -> LearningRendering?
    let onNewEntry: () -> Void
    let onPhotoWriting: () -> Void
    let onListenOne: () -> Void
    let onLanguageSpaceAction: () -> Void
    let onSelectEntry: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            titleKey: "tab.today",
            languageSpace: languageSpace,
            statusTextKey: "phone.today.status",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            HeroActionCard(
                languageSpace: languageSpace,
                onNewEntry: onNewEntry,
                onPhotoWriting: onPhotoWriting,
                onListenOne: onListenOne
            )
            SectionHeader(titleKey: "phone.today.recent.title", subtitleKey: "phone.today.recent.subtitle")
            if entries.isEmpty {
                EmptyEntryPanel(onNewEntry: onNewEntry)
            } else {
                ForEach(entries.prefix(2)) { entry in
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

struct EntriesView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let onNewEntry: () -> Void
    let onLanguageSpaceAction: () -> Void
    let onSelectEntry: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            titleKey: "tab.entries",
            languageSpace: languageSpace,
            statusTextKey: "phone.entries.status",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            HStack {
                SectionHeader(titleKey: "phone.entries.continue.title", subtitleKey: "phone.entries.continue.subtitle")
                Spacer()
                Button(action: onNewEntry) {
                    Label {
                        localizedText("common.newEntry.short")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            ForEach(entries) { entry in
                Button {
                    onSelectEntry(entry)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(.headline)
                            Text("\(entry.displaySourceTitle) · \(languageSpace.targetLanguage) · \(entry.scene)")
                                .font(.footnote)
                                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                    .langoPanel(padding: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PracticeView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let repository: InMemoryLearningContentRepository
    let onLanguageSpaceAction: () -> Void
    let onPractice: (LearningEntry) -> Void

    var body: some View {
        PhonePage(
            titleKey: "tab.practice",
            languageSpace: languageSpace,
            statusTextKey: "phone.practice.status",
            statusArgument: languageSpace.targetLanguage,
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            SectionHeader(titleKey: "phone.practice.fromLife.title", subtitleKey: "phone.practice.fromLife.subtitle")
            if entries.isEmpty {
                LocalizedCompactPanel(
                    titleKey: "phone.practice.empty.title",
                    textKey: "phone.practice.empty.body",
                    systemImage: "waveform"
                )
            } else {
                ForEach(entries) { entry in
                    let items = repository.practiceItems(for: entry.id)
                    if items.isEmpty {
                        CapabilityStatusRow(
                            title: entry.title,
                            localizedSummaryKey: "practice.empty.summary",
                            status: .unavailable,
                            systemImage: "waveform",
                            action: nil
                        )
                    } else {
                        ForEach(items) { item in
                            CapabilityStatusRow(
                                title: item.title,
                                summary: "\(entry.title) · \(item.summary)",
                                status: .mockOnly,
                                systemImage: icon(for: item.kind),
                                action: { onPractice(entry) }
                            )
                        }
                    }
                }
            }
        }
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

    var body: some View {
        PhonePage(
            titleKey: "tab.memory",
            languageSpace: languageSpace,
            statusTextKey: "phone.memory.status",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            SectionHeader(titleKey: "phone.memory.personal.title", subtitleKey: "phone.memory.personal.subtitle")
            ForEach(memoryItems) { item in
                CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
            }
            LocalizedCompactPanel(
                titleKey: "memory.vectorIndex.title",
                textKey: "memory.vectorIndex.body",
                systemImage: "square.stack.3d.up"
            )
        }
    }
}

struct SettingsView: View {
    let languageSpace: LanguageSpacePreview
    let capabilities: [SettingsCapability]
    let onLanguageSpaceAction: () -> Void
    let onSelectCapability: (SettingsCapability.Kind) -> Void

    var body: some View {
        PhonePage(
            titleKey: "tab.settings",
            languageSpace: languageSpace,
            statusTextKey: "phone.settings.status",
            onLanguageSpaceAction: onLanguageSpaceAction
        ) {
            SectionHeader(
                titleKey: "phone.settings.currentSpace.title",
                subtitleKey: "phone.settings.currentSpace.subtitle"
            )
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
    let statusTextKey: String
    var statusArgument: String?
    let onLanguageSpaceAction: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhoneContextHeader(languageSpace: languageSpace, statusText: statusText)
                content
            }
            .padding(20)
            .padding(.bottom, 92)
        }
        .navigationTitle(localizedText(titleKey))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: onLanguageSpaceAction) {
                    Image(systemName: "chevron.down.circle")
                }
                .accessibilityLabel(localizedText("languageSpace.switcher.label"))
                .accessibilityHint(localizedText("languageSpace.switcher.hint"))
            }
        }
        .langoPageBackground()
    }

    private var statusText: String {
        if let statusArgument {
            return localizedString(statusTextKey, statusArgument)
        }

        return localizedString(statusTextKey)
    }
}
