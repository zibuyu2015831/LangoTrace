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
    @State private var selectedScene: String?
    @Environment(\.memoryDepositActions) private var memoryDepositActions
    @State private var depositedEntryIDs: Set<String> = []

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
            HStack(spacing: 8) {
                FilterChipRow(selectedFilter: $selectedFilter)
                if !availableScenes.isEmpty {
                    SceneFilterMenu(
                        availableScenes: availableScenes,
                        selectedScene: $selectedScene
                    )
                }
            }
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
        .task(id: languageSpace.id) {
            // Facet selections are per-space UI state: switching the language
            // space resets the scene facet instead of carrying a stale value.
            selectedScene = nil
            depositedEntryIDs = await memoryDepositActions.depositedEntryIDs(languageSpace.id)
        }
    }

    private var availableScenes: [String] {
        EntrySceneFacet.availableScenes(in: entries)
    }

    private var filteredEntries: [LearningEntry] {
        let sceneNarrowed = EntrySceneFacet.entriesMatching(
            scene: EntrySceneFacet.normalizedSelection(selectedScene, in: entries),
            in: entries
        )
        return sceneNarrowed.filter { entry in
            selectedFilter.includes(
                entry: entry,
                hasMaterialWithoutRecording: practiceReadiness[entry.id] == false,
                hasPhotoAttachment: false,
                hasDepositedMemory: depositedEntryIDs.contains(entry.id)
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
        EntryTimelineFilter.allCases
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

private struct SceneFilterMenu: View {
    let availableScenes: [String]
    @Binding var selectedScene: String?

    @Environment(\.locale) private var locale

    var body: some View {
        Menu {
            Button {
                selectedScene = nil
            } label: {
                if selectedScene == nil {
                    Label(localizedString("filter.scene.all", locale: locale), systemImage: "checkmark")
                } else {
                    Text(localizedString("filter.scene.all", locale: locale))
                }
            }
            Divider()
            ForEach(availableScenes, id: \.self) { scene in
                Button {
                    selectedScene = scene
                } label: {
                    // Scene labels resolve upstream: preset slugs localize,
                    // free-form scene text is user content shown verbatim.
                    if selectedScene == scene {
                        Label(EntrySceneDisplay.label(forStoredScene: scene), systemImage: "checkmark")
                    } else {
                        Text(EntrySceneDisplay.label(forStoredScene: scene))
                    }
                }
            }
        } label: {
            Image(systemName: selectedScene == nil ? "tag" : "tag.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(
                    selectedScene == nil
                        ? LangoTraceDesign.ColorToken.ink
                        : LangoTraceDesign.ColorToken.whiteInk
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    selectedScene == nil
                        ? LangoTraceDesign.ColorToken.surfaceBase
                        : LangoTraceDesign.ColorToken.accent
                )
                .clipShape(Capsule())
        }
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(localizedString("phone.sceneFilter.label", locale: locale)))
    }
}

private struct FilterChipButton: View {
    let titleKey: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            LocalizedText(titleKey)
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
        .accessibilityLabel(Text(localizedString(titleKey, locale: locale)))
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
    var onCompanion: (() -> Void)?

    @Environment(\.companionFeatureEnabled) private var companionFeatureEnabled

    var body: some View {
        PhonePage(
            titleKey: "tab.practice",
            languageSpace: languageSpace,
            onLanguageSpaceAction: onLanguageSpaceAction,
            onSettingsAction: onSettingsAction
        ) {
            if companionFeatureEnabled, let onCompanion {
                CompanionEntryCard(action: onCompanion)
            }
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

    @Environment(\.memoryDepositActions) private var memoryDepositActions
    @Environment(\.memoryReviewActions) private var memoryReviewActions
    @State private var deposited: [DepositedMemoryItem] = []
    @State private var depositedCandidateIDs: Set<String> = []
    @State private var depositingCandidateID: String?
    @State private var statistics: MemoryStatistics = .zero
    @State private var isReviewing = false

    var body: some View {
        PhonePage(
            titleKey: "tab.memory",
            languageSpace: languageSpace,
            onLanguageSpaceAction: onLanguageSpaceAction,
            onSettingsAction: onSettingsAction
        ) {
            MemoryStatisticsBar(statistics: statistics, onStartReview: { isReviewing = true })
            depositedSection
            SectionHeader(titleKey: "phone.memory.personal.title", subtitleKey: "phone.memory.personal.subtitle")
            if memoryItems.isEmpty {
                LocalizedCompactPanel(
                    titleKey: "memory.empty.title",
                    textKey: "memory.empty.body",
                    systemImage: "bookmark"
                )
            } else {
                ForEach(memoryItems) { item in
                    candidateRow(item)
                }
            }
        }
        .task(id: languageSpace.id) {
            await reloadDeposited()
        }
        .sheet(isPresented: $isReviewing, onDismiss: { Task { await reloadDeposited() } }) {
            MemoryReviewSessionView(spaceID: languageSpace.id, onClose: { isReviewing = false })
        }
    }

    @ViewBuilder
    private var depositedSection: some View {
        SectionHeader(titleKey: "phone.memory.deposited.title", subtitleKey: "phone.memory.deposited.subtitle")
        if deposited.isEmpty {
            LocalizedCompactPanel(
                titleKey: "memory.deposited.empty.title",
                textKey: "memory.deposited.empty.body",
                systemImage: "checkmark.seal"
            )
        } else {
            ForEach(deposited) { item in
                CompactPanel(title: item.text, text: item.note, systemImage: "checkmark.seal")
            }
        }
    }

    private func candidateRow(_ item: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CompactPanel(title: item.text, text: item.note, systemImage: "bookmark")
            if depositedCandidateIDs.contains(item.id) {
                Label(localizedString("memory.deposit.added"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.privacyLocal)
            } else {
                Button {
                    Task { await deposit(item) }
                } label: {
                    Label(localizedString("memory.deposit.action"), systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .disabled(depositingCandidateID == item.id)
            }
        }
    }

    private func deposit(_ item: MemoryItem) async {
        depositingCandidateID = item.id
        let ok = await memoryDepositActions.depositCandidate(item.id, languageSpace.id)
        depositingCandidateID = nil
        if ok {
            depositedCandidateIDs.insert(item.id)
            await reloadDeposited()
        }
    }

    private func reloadDeposited() async {
        deposited = await memoryDepositActions.listDeposited(languageSpace.id)
        depositedCandidateIDs = await memoryDepositActions.depositedCandidateIDs(languageSpace.id)
        statistics = await memoryReviewActions.statistics(languageSpace.id)
    }
}

/// Shared low-pressure memory dashboard bar (E8): this-week deposited, due, and
/// mastered counts plus the "start review" entry. Used on all three platforms.
struct MemoryStatisticsBar: View {
    let statistics: MemoryStatistics
    let onStartReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                statColumn(titleKey: "memory.stats.deposited", value: statistics.depositedThisWeek)
                statColumn(titleKey: "memory.stats.due", value: statistics.dueCount)
                statColumn(titleKey: "memory.stats.mastered", value: statistics.masteredCount)
            }
            Button(action: onStartReview) {
                Label(localizedString("memory.review.start"), systemImage: "play.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.whiteInk)
            .background(LangoTraceDesign.ColorToken.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .langoPanel()
    }

    private func statColumn(titleKey: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            localizedText(titleKey)
                .font(.caption)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
    }
}

struct SettingsView: View {
    let languageSpace: LanguageSpacePreview
    let capabilities: [SettingsCapability]
    let settingsStatus: SettingsStatusProjection
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onLanguageSpaceAction: () -> Void
    let onSettingsAction: (() -> Void)?
    let onSelectCapability: (SettingsCapability.Kind) -> Void
    var onSelectLearnerProfile: (() -> Void)?
    var onAppearRefresh: () -> Void = {}
    @Environment(\.companionFeatureEnabled) private var companionFeatureEnabled

    var body: some View {
        PhonePage(
            titleKey: "tab.settings",
            languageSpace: languageSpace,
            onLanguageSpaceAction: onLanguageSpaceAction,
            onSettingsAction: onSettingsAction,
            showsContextHeader: false
        ) {
            if let onSelectLearnerProfile {
                LearnerProfileSettingsRow(action: onSelectLearnerProfile)
            }
            ForEach(capabilities) { capability in
                CapabilityStatusRow(
                    localizedTitleKey: capability.kind.localizedTitleKey,
                    localizedSummaryKey: settingsCapabilityDetailLocalizationKeys(for: capability.kind).summary,
                    status: capability.status,
                    systemImage: capability.kind.systemImage,
                    showsStatusBadge: false,
                    action: { onSelectCapability(capability.kind) }
                )
                .trailingValue(settingsRowValue(
                    for: capability.kind,
                    status: settingsStatus,
                    interfaceLanguage: interfaceLanguagePreference,
                    appearance: appearancePreference,
                    companionEnabled: companionFeatureEnabled
                ))
            }
        }
        .onAppear(perform: onAppearRefresh)
    }
}

/// Settings entry row for the learner profile overview (LM02). An independent
/// navigation item — deliberately not a `SettingsCapability` (the profile is not
/// a status-bearing configuration capability).
struct LearnerProfileSettingsRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    localizedText("learnerProfile.title")
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    localizedText("settings.learnerProfile.summary")
                        .font(.caption)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            // Mirror CapabilityStatusRow: card chrome inside the button label so the whole
            // card is tappable and the row matches every capability row in the settings list.
            .frame(maxWidth: .infinity, alignment: .leading)
            .langoPanel(padding: 16)
        }
        .buttonStyle(.plain)
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
        let page = ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            // Reclaim the large-title band but keep 20pt breathing room below the
            // navigation bar (design review: 0pt feels oppressive).
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 92)
        }
        .langoPageBackground()

        if showsContextHeader {
            page.phoneRootContextToolbar(
                titleKey: titleKey,
                languageSpace: languageSpace,
                onLanguageSpaceAction: onLanguageSpaceAction,
                onSettingsAction: onSettingsAction
            )
        } else {
            // SettingsView and other non-root consumers keep a plain inline title
            // with no language capsule / gear injected.
            page.navigationTitle(localizedText(titleKey))
        }
    }
}
