import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PadMainView: View {
    let languageSpace: LanguageSpacePreview
    let contentRepository: InMemoryLearningContentRepository

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isTimelineVisible = true
    @State private var isLearningPanelVisible = true
    @State private var selectedEntryID: String?
    @State private var route: PadWorkspaceRoute = .workspace
    @State private var presentedSheet: PadSheet?
    @State private var activeFilter: PadFilter = .all
    @State private var contentRevision = 0

    var body: some View {
        VStack(spacing: 0) {
            PadWorkspaceBar(
                isTimelineVisible: isTimelineVisible,
                isLearningPanelVisible: isLearningPanelVisible,
                onToggleTimeline: { isTimelineVisible.toggle() },
                onToggleLearningPanel: { isLearningPanelVisible.toggle() },
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
                            .transition(panelTransition(edge: .trailing))
                            .simultaneousGesture(
                                panelGesture(
                                    workspaceWidth: proxy.size.width,
                                    startXOffset: max(0, proxy.size.width - 360)
                                )
                            )
                    }
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
                    let entry = contentRepository.createEntry(
                        spaceID: languageSpace.id,
                        title: title,
                        body: body,
                        source: .typedText
                    )
                    contentRevision += 1
                    selectedEntryID = entry.id
                    route = .entryDetail(entry.id)
                    presentedSheet = nil
                }
            }
        }
        .onAppear {
            contentRepository.ensureSeeded(spaceID: languageSpace.id)
            selectedEntryID = selectedEntryID ?? contentRepository.selectedEntry(for: languageSpace.id)?.id
            if shouldPreferSingleMainColumn {
                isLearningPanelVisible = false
            }
            contentRevision += 1
        }
    }

    private var entries: [LearningEntry] {
        _ = contentRevision
        return contentRepository.entries(for: languageSpace.id)
    }

    private var memoryItems: [MemoryItem] {
        _ = contentRevision
        return contentRepository.memoryItems(for: languageSpace.id)
    }

    private var filteredEntries: [LearningEntry] {
        entries.filter { activeFilter.includes(entry: $0, memoryItems: memoryItems) }
    }

    private var selectedEntry: LearningEntry? {
        if let selectedEntryID {
            if let entry = entries.first(where: { $0.id == selectedEntryID }) {
                return entry
            }
        }

        return contentRepository.selectedEntry(for: languageSpace.id)
    }

    private var selectedRendering: LearningRendering? {
        guard let selectedEntry else {
            return nil
        }

        return contentRepository.rendering(for: selectedEntry.id)
    }

    private var shouldPreferSingleMainColumn: Bool {
        horizontalSizeClass == .compact
    }

    private var settingsCapabilities: [SettingsCapability] {
        contentRepository.settingsCapabilities(for: languageSpace.id)
    }

    private var panelAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
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

    private var sidebar: some View {
        PadSidebarView(
            languageSpace: languageSpace,
            entries: entries,
            filteredEntries: filteredEntries,
            memoryItems: memoryItems,
            selectedEntry: selectedEntry,
            activeFilter: activeFilter,
            route: route,
            onSelectEntry: selectEntry,
            onSelectFilter: selectFilter,
            onRoute: { route = $0 }
        )
    }

    private var writingDesk: some View {
        PadWorkspaceContentView(
            route: route,
            languageSpace: languageSpace,
            entries: entries,
            selectedEntry: selectedEntry,
            selectedRendering: selectedRendering,
            memoryItems: memoryItems,
            settingsCapabilities: settingsCapabilities,
            contentRepository: contentRepository,
            onRoute: { route = $0 }
        )
    }

    private var learningPanel: some View {
        PadLearningPanelView(
            selectedEntry: selectedEntry,
            selectedRendering: selectedRendering,
            memoryItems: memoryItems,
            contentRepository: contentRepository,
            onRoute: { route = $0 }
        )
    }

    private func selectEntry(_ entry: LearningEntry) {
        selectedEntryID = entry.id
        contentRepository.selectEntry(id: entry.id, spaceID: languageSpace.id)
        route = .entryDetail(entry.id)
    }

    private func selectFilter(_ filter: PadFilter) {
        activeFilter = filter
        route = .workspace
    }
}
