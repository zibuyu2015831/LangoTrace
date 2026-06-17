import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PhoneRecordWorkspaceView: View {
    let languageSpace: LanguageSpacePreview
    let entries: [LearningEntry]
    let practiceReadiness: [String: Bool]
    let renderingForEntry: (LearningEntry) -> LearningRendering?
    let onNewEntry: () -> Void
    let onPhotoWriting: () -> Void
    let onLanguageSpaceAction: () -> Void
    var onSettingsAction: (() -> Void)?
    let onSelectEntry: (LearningEntry) -> Void

    @State private var selectedFilter: EntryTimelineFilter = .all

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
            FilterChipRow(selectedFilter: $selectedFilter)
            if entries.isEmpty {
                LocalizedCompactPanel(
                    titleKey: "timeline.empty.title",
                    textKey: "timeline.empty.body",
                    systemImage: "square.and.pencil"
                )
            } else if filteredEntries.isEmpty {
                LocalizedCompactPanel(
                    titleKey: "timeline.filter.empty.title",
                    textKey: "timeline.filter.empty.body",
                    systemImage: "line.3.horizontal.decrease"
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                    ForEach(dayGroups) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                EntryCard(
                                    entry: entry,
                                    targetLanguage: languageSpace.targetLanguage,
                                    rendering: renderingForEntry(entry),
                                    action: { onSelectEntry(entry) }
                                )
                            }
                        } header: {
                            Text(sectionHeaderTitle(for: group.date))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    private var filteredEntries: [LearningEntry] {
        entries.filter { entry in
            selectedFilter.includes(
                entry: entry,
                hasMaterialWithoutRecording: practiceReadiness[entry.id] == false,
                hasPhotoAttachment: false
            )
        }
    }

    private var dayGroups: [EntryDayGroup] {
        groupEntriesByDay(filteredEntries)
    }

    private func sectionHeaderTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return localizedString("timeline.section.today")
        } else if calendar.isDateInYesterday(date) {
            return localizedString("timeline.section.yesterday")
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

private struct FilterChipRow: View {
    @Binding var selectedFilter: EntryTimelineFilter

    private var visibleFilters: [EntryTimelineFilter] {
        EntryTimelineFilter.allCases.filter { $0 != .settled }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleFilters, id: \.self) { filter in
                    FilterChipButton(
                        titleKey: filter.titleKey,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct FilterChipButton: View {
    let titleKey: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            localizedText(titleKey)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(
                    isSelected
                        ? LangoTraceDesign.ColorToken.whiteInk
                        : LangoTraceDesign.ColorToken.ink
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? LangoTraceDesign.ColorToken.accent
                        : LangoTraceDesign.ColorToken.surfaceBase
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(localizedText(titleKey))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        let practiceLabel = entry.practiceStatus.displayLabel
        let targetPreview = rendering?.sentences.first?.targetText ?? practiceLabel
        return PracticeEntryCardProjection(
            title: entry.title,
            targetPreview: targetPreview,
            sentenceCount: sentenceCount,
            completedCount: 0,
            problemCount: 0,
            statusText: practiceLabel
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
