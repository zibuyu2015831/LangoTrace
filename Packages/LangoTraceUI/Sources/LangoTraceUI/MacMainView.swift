import LangoTraceCore
import LangoTraceData
import SwiftUI

struct MacMainView: View {
    let languageSpace: LanguageSpacePreview
    let contentRepository: InMemoryLearningContentRepository
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSidebarVisible = true
    @State private var isInspectorVisible = true
    @State private var selectedSection: MacWorkspaceSection = .today
    @State private var selectedEntryID: String?
    @State private var route: MacWorkspaceRoute = .overview
    @State private var isEntryEditorPresented = false
    @State private var contentRevision = 0

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .transition(panelTransition(edge: .leading))
                Divider()
            }
            main
            if isInspectorVisible {
                Divider()
                inspector
                    .transition(panelTransition(edge: .trailing))
            }
        }
        .frame(minWidth: minimumWindowWidth, minHeight: 720)
        .langoPageBackground()
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Label(isSidebarVisible ? "隐藏侧边栏" : "显示侧边栏", systemImage: "sidebar.left")
                }
                Button {
                    isInspectorVisible.toggle()
                } label: {
                    Label(isInspectorVisible ? "隐藏检查器" : "显示检查器", systemImage: "sidebar.right")
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    selectedSection = .entries
                    route = .unavailable("search")
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                Button {
                    isEntryEditorPresented = true
                } label: {
                    Label("新建记录", systemImage: "plus")
                }
            }
        }
        .animation(panelAnimation, value: isSidebarVisible)
        .animation(panelAnimation, value: isInspectorVisible)
        .sheet(isPresented: $isEntryEditorPresented) {
            EntryEditorView(languageSpace: languageSpace) { title, body in
                let entry = contentRepository.createEntry(
                    spaceID: languageSpace.id,
                    title: title,
                    body: body,
                    source: .typedText
                )
                contentRevision += 1
                selectedEntryID = entry.id
                selectedSection = .entries
                route = .entryDetail(entry.id)
                isEntryEditorPresented = false
            }
        }
        .onAppear {
            contentRepository.ensureSeeded(spaceID: languageSpace.id)
            selectedEntryID = selectedEntryID ?? contentRepository.selectedEntry(for: languageSpace.id)?.id
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

    private var selectedEntry: LearningEntry? {
        if let selectedEntryID, let entry = entries.first(where: { $0.id == selectedEntryID }) {
            return entry
        }

        return contentRepository.selectedEntry(for: languageSpace.id)
    }

    private var selectedRendering: LearningRendering? {
        guard let selectedEntry else {
            return nil
        }

        return contentRepository.rendering(for: selectedEntry.id)
    }

    private var settingsCapabilities: [SettingsCapability] {
        contentRepository.settingsCapabilities(for: languageSpace.id)
    }

    private var minimumWindowWidth: CGFloat {
        MacWindowLayout.minimumWidth(
            sidebarVisible: isSidebarVisible,
            inspectorVisible: isInspectorVisible
        )
    }

    private var panelAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: LangoTraceDesign.Motion.panelTransitionDuration)
    }

    private func panelTransition(edge: Edge) -> AnyTransition {
        reduceMotion ? .identity : .move(edge: edge).combined(with: .opacity)
    }

    private func selectSection(_ section: MacWorkspaceSection) {
        selectedSection = section
        route = .overview
    }

    private func showEntry(_ entry: LearningEntry) {
        selectedEntryID = entry.id
        contentRepository.selectEntry(id: entry.id, spaceID: languageSpace.id)
        route = .entryDetail(entry.id)
    }

    private func routeFooterAction(_ action: MacFooterAction) {
        selectedSection = action.section
        route = action.route
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(ProductIdentity.displayName)
                .font(.title2.weight(.semibold))

            VStack(spacing: 8) {
                ForEach(MacWorkspaceSection.allCases, id: \.self) { section in
                    Button {
                        selectSection(section)
                    } label: {
                        SideItem(
                            title: section.title,
                            subtitle: section.subtitle(
                                entriesCount: entries.count,
                                memoryCount: memoryItems.count
                            ),
                            active: selectedSection == section
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                    .accessibilityValue(selectedSection == section ? "当前选中" : "未选中")
                }
            }

            Spacer()
            LanguageSpaceFooter(
                languageSpace: languageSpace,
                aiStatus: .notConfigured,
                syncStatus: .off,
                isCompact: true,
                onLanguageSpace: { routeFooterAction(.languageSpace) },
                onAIStatus: { routeFooterAction(.aiProvider) },
                onSyncStatus: { routeFooterAction(.sync) },
                onSettings: { routeFooterAction(.settings) }
            )
        }
        .padding(24)
        .frame(width: LangoTraceDesign.Density.macSidebarWidth, alignment: .topLeading)
    }

    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                MacWorkspaceContentView(
                    selectedSection: selectedSection,
                    route: route,
                    languageSpace: languageSpace,
                    entries: entries,
                    selectedEntryID: selectedEntryID,
                    selectedEntry: selectedEntry,
                    selectedRendering: selectedRendering,
                    memoryItems: memoryItems,
                    settingsCapabilities: settingsCapabilities,
                    contentRepository: contentRepository,
                    interfaceLanguagePreference: interfaceLanguagePreference,
                    onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                    onShowEntry: showEntry,
                    onRoute: { route = $0 }
                )
            }
            .padding(26)
        }
        .frame(minWidth: 500, maxWidth: .infinity)
        .layoutPriority(1)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedSection.title)
                    .font(.largeTitle.weight(.semibold))
                Text(selectedSection.description)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            Spacer()
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("INSPECTOR")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                MacInspectorContent(
                    route: route,
                    selectedSection: selectedSection,
                    entries: entries,
                    settingsCapabilities: settingsCapabilities,
                    contentRepository: contentRepository
                )
                Spacer()
            }
            .padding(24)
        }
        .frame(width: LangoTraceDesign.Density.macInspectorWidth, alignment: .topLeading)
    }
}
