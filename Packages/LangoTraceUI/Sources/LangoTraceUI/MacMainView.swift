import LangoTraceCore
import LangoTraceData
import SwiftUI

struct MacMainView: View {
    let languageSpace: LanguageSpacePreview
    @ObservedObject var contentStore: LearningContentStore
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSidebarVisible = true
    @State private var isInspectorVisible = true
    @State private var selectedSection: MacWorkspaceSection = .today
    @State private var selectedEntryID: String?
    @State private var route: MacWorkspaceRoute = .overview
    @State private var isEntryEditorPresented = false

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
                    Label {
                        localizedText(isSidebarVisible ? "mac.sidebar.hide" : "mac.sidebar.show")
                    } icon: {
                        Image(systemName: "sidebar.left")
                    }
                }
                Button {
                    isInspectorVisible.toggle()
                } label: {
                    Label {
                        localizedText(isInspectorVisible ? "mac.inspector.hide" : "mac.inspector.show")
                    } icon: {
                        Image(systemName: "sidebar.right")
                    }
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    selectedSection = .entries
                    route = .unavailable("search")
                } label: {
                    Label {
                        localizedText("common.search")
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                Button {
                    isEntryEditorPresented = true
                } label: {
                    Label {
                        localizedText("common.newEntry")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .animation(panelAnimation, value: isSidebarVisible)
        .animation(panelAnimation, value: isInspectorVisible)
        .sheet(isPresented: $isEntryEditorPresented) {
            EntryEditorView(languageSpace: languageSpace) { title, body in
                let entry = contentStore.createEntry(
                    title: title,
                    body: body,
                    source: .typedText
                )
                selectedEntryID = entry.id
                selectedSection = .entries
                route = .entryDetail(entry.id)
                isEntryEditorPresented = false
            }
        }
        .onAppear {
            contentStore.ensureSeeded()
            selectedEntryID = selectedEntryID ?? contentStore.selectedEntry?.id
        }
    }

    private var entries: [LearningEntry] {
        contentStore.entries
    }

    private var memoryItems: [MemoryItem] {
        contentStore.memoryItems
    }

    private var selectedEntry: LearningEntry? {
        if let selectedEntryID, let entry = entries.first(where: { $0.id == selectedEntryID }) {
            return entry
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
        contentStore.selectEntry(entry)
        route = .entryDetail(entry.id)
    }

    private func routeFooterAction(_ action: MacFooterAction) {
        selectedSection = action.section
        route = action.route
    }

    private func selectionAccessibilityValue(for section: MacWorkspaceSection) -> Text {
        localizedText(selectedSection == section ? "accessibility.selected" : "accessibility.unselected")
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
                            title: localizedString(section.titleKey),
                            subtitle: section.subtitle(
                                entriesCount: entries.count,
                                memoryCount: memoryItems.count
                            ),
                            active: selectedSection == section
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizedText(section.titleKey))
                    .accessibilityValue(selectionAccessibilityValue(for: section))
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
                    contentStore: contentStore,
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
                localizedText(selectedSection.titleKey)
                    .font(.largeTitle.weight(.semibold))
                localizedText(selectedSection.descriptionKey)
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
                    contentStore: contentStore
                )
                Spacer()
            }
            .padding(24)
        }
        .frame(width: LangoTraceDesign.Density.macInspectorWidth, alignment: .topLeading)
    }
}
