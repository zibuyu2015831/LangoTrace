import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PadMainView: View {
    let languageSpace: LanguageSpacePreview
    let languageSpaces: [LanguageSpace]
    @ObservedObject var contentStore: LearningContentStore
    @ObservedObject var readingLibraryStore: ReadingLibraryStore
    let readingExplanationAction: ReadingExplanationAction
    let readingTTSAction: ReadingTTSAction
    let readingCacheStorage: (any ExplanationCacheStorage)?
    let practiceActions: PracticeActions
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    let onSelectLanguageSpace: (String) -> Void
    let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    let onDeleteLanguageSpace: (String) -> Void
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isTimelineVisible = true
    @State private var isLearningPanelVisible = true
    @State private var selectedEntryID: String?
    @State private var route: PadWorkspaceRoute = .workspace
    @State private var presentedSheet: PadSheet?
    @State private var activeFilter: EntryTimelineFilter = .all
    @Environment(\.memoryDepositActions) private var memoryDepositActions
    @State private var depositedEntryIDs: Set<String> = []

    private let learningPanelTrailingInset: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            PadWorkspaceBar(
                isTimelineVisible: isTimelineVisible,
                isLearningPanelVisible: isLearningPanelVisible,
                onToggleTimeline: { isTimelineVisible.toggle() },
                onToggleLearningPanel: { isLearningPanelVisible.toggle() },
                onSearch: { presentedSheet = .search },
                onNewEntry: { presentedSheet = .entryEditor }
            )
            Divider()
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    if isTimelineVisible {
                        sidebar
                            .transition(panelTransition(edge: .leading))
                            .simultaneousGesture(panelGesture(workspaceWidth: proxy.size.width))
                        Divider()
                    }
                    writingDesk
                    if isLearningPanelVisible {
                        Divider()
                        learningPanel
                            .padding(.trailing, learningPanelTrailingInset)
                            .transition(panelTransition(edge: .trailing))
                            .simultaneousGesture(
                                panelGesture(
                                    workspaceWidth: proxy.size.width,
                                    startXOffset: learningPanelGestureStartX(workspaceWidth: proxy.size.width)
                                )
                            )
                    }
                }
                .onAppear {
                    applyAdaptivePanelVisibility(workspaceWidth: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, width in
                    applyAdaptivePanelVisibility(workspaceWidth: width)
                }
                .overlay(alignment: .leading) {
                    if !isTimelineVisible {
                        edgeGestureZone(workspaceWidth: proxy.size.width)
                    }
                }
                .overlay(alignment: .trailing) {
                    if !isLearningPanelVisible {
                        edgeGestureZone(
                            workspaceWidth: proxy.size.width,
                            startXOffset: max(0, proxy.size.width - 32)
                        )
                    }
                }
            }
        }
        .langoPageBackground()
        .animation(panelAnimation, value: isTimelineVisible)
        .animation(panelAnimation, value: isLearningPanelVisible)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .entryEditor:
                EntryEditorView(languageSpace: languageSpace) { title, body in
                    let entry = try contentStore.createEntry(
                        title: title,
                        body: body,
                        source: .typedText
                    )
                    selectedEntryID = entry.id
                    setRoute(.entryDetail(entry.id))
                    presentedSheet = nil
                }
            case .search:
                SearchPaletteView(
                    spaceID: languageSpace.id,
                    onSelect: { hit in
                        presentedSheet = nil
                        if hit.kind == .entry {
                            selectedEntryID = hit.objectID
                            setRoute(.entryDetail(hit.objectID))
                        }
                    },
                    onClose: { presentedSheet = nil }
                )
            }
        }
        .onAppear {
            contentStore.ensureSeeded()
            selectedEntryID = selectedEntryID ?? contentStore.selectedEntry?.id
            applyAdaptivePanelVisibility()
        }
        .task(id: languageSpace.id) {
            depositedEntryIDs = await memoryDepositActions.depositedEntryIDs(languageSpace.id)
        }
        .onChange(of: horizontalSizeClass) {
            applyAdaptivePanelVisibility()
        }
    }

    private var entries: [LearningEntry] {
        contentStore.entries
    }

    private var memoryItems: [MemoryItem] {
        contentStore.memoryItems
    }

    private var filteredEntries: [LearningEntry] {
        entries.filter { entry in
            activeFilter.includes(
                entry: entry,
                hasMaterialWithoutRecording: contentStore.practiceReadiness[entry.id] == false,
                hasPhotoAttachment: false,
                hasDepositedMemory: depositedEntryIDs.contains(entry.id)
            )
        }
    }

    private var selectedEntry: LearningEntry? {
        if let selectedEntryID {
            if let entry = entries.first(where: { $0.id == selectedEntryID }) {
                return entry
            }
        }

        return contentStore.selectedEntry
    }

    private var selectedRendering: LearningRendering? {
        guard let selectedEntry else {
            return nil
        }

        return contentStore.rendering(for: selectedEntry)
    }

    private var settingsCapabilities: [SettingsCapability] {
        contentStore.settingsCapabilities
    }

    private var panelAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: LangoTraceDesign.Motion.panelTransitionDuration)
    }

    private func panelTransition(edge: Edge) -> AnyTransition {
        reduceMotion ? .identity : .move(edge: edge).combined(with: .opacity)
    }

    private func edgeGestureZone(workspaceWidth: CGFloat, startXOffset: CGFloat = 0) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: 32)
            .gesture(panelGesture(workspaceWidth: workspaceWidth, startXOffset: startXOffset))
    }

    private func learningPanelGestureStartX(workspaceWidth: CGFloat) -> CGFloat {
        max(0, workspaceWidth - 360 - learningPanelTrailingInset)
    }

    private func panelGesture(workspaceWidth: CGFloat, startXOffset: CGFloat = 0) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                let context = PadPanelGestureContext(
                    startX: startXOffset + value.startLocation.x,
                    translationX: value.translation.width,
                    translationY: value.translation.height,
                    workspaceWidth: workspaceWidth,
                    isTimelineVisible: isTimelineVisible,
                    isLearningPanelVisible: isLearningPanelVisible
                )

                guard let action = PadPanelGestureAction.action(in: context) else {
                    return
                }

                applyPanelGestureAction(action)
            }
    }

    private func applyPanelGestureAction(_ action: PadPanelGestureAction) {
        switch action {
        case .showTimeline:
            isTimelineVisible = true
        case .hideTimeline:
            isTimelineVisible = false
        case .showLearningPanel:
            isLearningPanelVisible = true
        case .hideLearningPanel:
            isLearningPanelVisible = false
        }
    }

    private func applyAdaptivePanelVisibility(workspaceWidth: CGFloat? = nil) {
        let preferred = PadSettingsFocusPolicy.visibilityAfterResize(
            route: route,
            workspaceWidth: workspaceWidth,
            horizontalSizeClass: horizontalSizeClass,
            current: PadPanelVisibility(timeline: isTimelineVisible, learningPanel: isLearningPanelVisible)
        )

        isTimelineVisible = preferred.timeline
        isLearningPanelVisible = preferred.learningPanel
    }

    private var sidebar: some View {
        PadSidebarView(
            languageSpace: languageSpace,
            entries: entries,
            depositedEntryIDs: depositedEntryIDs,
            filteredEntries: filteredEntries,
            practiceReadiness: contentStore.practiceReadiness,
            renderingForEntry: { contentStore.rendering(for: $0) },
            selectedEntry: selectedEntry,
            activeFilter: activeFilter,
            route: route,
            aiStatus: contentStore.settingsStatus.aiProvider.footerStatus,
            syncStatus: contentStore.settingsStatus.sync.footerStatus,
            onSelectEntry: selectEntry,
            onSelectFilter: selectFilter,
            onRoute: setRoute
        )
        .task { await contentStore.refreshSettingsStatus() }
    }

    private var writingDesk: some View {
        PadWorkspaceContentView(
            route: route,
            languageSpace: languageSpace,
            entries: entries,
            selectedEntry: selectedEntry,
            selectedRendering: selectedRendering,
            memoryItems: memoryItems,
            languageSpaces: languageSpaces,
            settingsCapabilities: settingsCapabilities,
            contentStore: contentStore,
            readingLibraryStore: readingLibraryStore,
            readingExplanationAction: readingExplanationAction,
            readingTTSAction: readingTTSAction,
            readingCacheStorage: readingCacheStorage,
            practiceActions: practiceActions,
            interfaceLanguagePreference: interfaceLanguagePreference,
            appearancePreference: appearancePreference,
            onAddLanguageSpace: onAddLanguageSpace,
            onSelectLanguageSpace: onSelectLanguageSpace,
            onUpdateLanguageSpace: onUpdateLanguageSpace,
            onDeleteLanguageSpace: onDeleteLanguageSpace,
            onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
            onAppearancePreferenceChange: onAppearancePreferenceChange,
            onRoute: setRoute
        )
    }

    private var learningPanel: some View {
        PadLearningPanelView(
            route: route,
            selectedEntry: selectedEntry,
            selectedRendering: selectedRendering,
            memoryItems: memoryItems,
            contentStore: contentStore,
            onRoute: setRoute
        )
    }

    private func selectEntry(_ entry: LearningEntry) {
        selectedEntryID = entry.id
        contentStore.selectEntry(entry)
        setRoute(.entryDetail(entry.id))
    }

    private func selectFilter(_ filter: EntryTimelineFilter) {
        activeFilter = filter
        setRoute(.workspace)
    }

    private func setRoute(_ newRoute: PadWorkspaceRoute) {
        let currentVisibility = PadPanelVisibility(timeline: isTimelineVisible, learningPanel: isLearningPanelVisible)
        route = newRoute
        let focusedVisibility = PadSettingsFocusPolicy.visibility(whenEntering: newRoute, current: currentVisibility)
        isTimelineVisible = focusedVisibility.timeline
        isLearningPanelVisible = focusedVisibility.learningPanel
    }
}
