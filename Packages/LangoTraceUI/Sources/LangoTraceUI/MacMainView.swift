import LangoTraceCore
import LangoTraceData
import SwiftUI

struct MacMainView: View {
    let languageSpace: LanguageSpacePreview
    let languageSpaces: [LanguageSpace]
    @ObservedObject var contentStore: LearningContentStore
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    let onSelectLanguageSpace: (String) -> Void
    let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    let onDeleteLanguageSpace: (String) -> Void
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void

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
        .overlay {
            if isEntryEditorPresented {
                MacEntryEditorOverlay(
                    languageSpace: languageSpace,
                    onCancel: closeEntryEditor,
                    onSave: saveEntry
                )
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(panelAnimation, value: isEntryEditorPresented)
        .onAppear {
            contentStore.ensureSeeded()
            selectedEntryID = selectedEntryID ?? contentStore.selectedEntry?.id
        }
        .onReceive(NotificationCenter.default.publisher(for: LangoTraceAppCommand.newEntry)) { _ in
            isEntryEditorPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: LangoTraceAppCommand.search)) { _ in
            selectedSection = .entries
            route = .unavailable("search")
        }
        .onReceive(NotificationCenter.default.publisher(for: LangoTraceAppCommand.toggleSidebar)) { _ in
            isSidebarVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: LangoTraceAppCommand.toggleInspector)) { _ in
            isInspectorVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: LangoTraceAppCommand.showSettings)) { _ in
            selectedSection = .settings
            route = .overview
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(ProductIdentity.displayName)
                .font(.title2.weight(.semibold))

            VStack(spacing: 8) {
                ForEach(MacWorkspaceSection.allCases, id: \.self) { section in
                    MacSidebarItem(
                        title: localizedString(section.titleKey),
                        subtitle: section.subtitle(
                            entriesCount: entries.count,
                            memoryCount: memoryItems.count
                        ),
                        active: selectedSection == section,
                        action: {
                            selectSection(section)
                        }
                    )
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
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.surfaceSidebar.opacity(0.72))
    }
}

private extension MacMainView {
    var main: some View {
        Group {
            if route.usesDedicatedMainScrolling {
                mainContent
                    .padding(26)
            } else {
                ScrollView {
                    mainContent
                        .padding(26)
                }
            }
        }
        .frame(minWidth: 500, maxWidth: .infinity)
        .layoutPriority(1)
    }

    var mainContent: some View {
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
                languageSpaces: languageSpaces,
                settingsCapabilities: settingsCapabilities,
                contentStore: contentStore,
                interfaceLanguagePreference: interfaceLanguagePreference,
                appearancePreference: appearancePreference,
                onAddLanguageSpace: onAddLanguageSpace,
                onSelectLanguageSpace: onSelectLanguageSpace,
                onUpdateLanguageSpace: onUpdateLanguageSpace,
                onDeleteLanguageSpace: onDeleteLanguageSpace,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                onAppearancePreferenceChange: onAppearancePreferenceChange,
                onShowEntry: showEntry,
                onRoute: { route = $0 }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var header: some View {
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

    var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                localizedText("mac.inspector.title")
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
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.surfaceInspector.opacity(0.58))
    }

    var panelAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: LangoTraceDesign.Motion.panelTransitionDuration)
    }

    func panelTransition(edge: Edge) -> AnyTransition {
        reduceMotion ? .identity : .move(edge: edge).combined(with: .opacity)
    }

    func closeEntryEditor() {
        isEntryEditorPresented = false
    }

    func saveEntry(title: String, body: String) {
        guard let entry = try? contentStore.createEntry(
            title: title,
            body: body,
            source: .typedText
        ) else { return }
        selectedEntryID = entry.id
        selectedSection = .entries
        route = .entryDetail(entry.id)
        isEntryEditorPresented = false
    }
}

private struct MacEntryEditorOverlay: View {
    let languageSpace: LanguageSpacePreview
    let onCancel: () -> Void
    let onSave: (String, String) -> Void

    var body: some View {
        ZStack {
            LangoTraceDesign.ColorToken.ink.opacity(0.20)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onCancel()
                }

            MacEntryEditorSheet(
                languageSpace: languageSpace,
                onCancel: onCancel,
                onSave: onSave
            )
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct MacSidebarItem: View {
    let title: String
    let subtitle: String
    let active: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(itemBackground)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                    .stroke(itemStroke, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: action) {
                Text(title)
            }
        }
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(localizedText(active ? "accessibility.selected" : "accessibility.unselected"))
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var itemBackground: Color {
        if active { return LangoTraceDesign.ColorToken.surfaceRaised }
        return isHovered ? LangoTraceDesign.ColorToken.elevatedPaper : .clear
    }

    private var itemStroke: Color {
        if active {
            return LangoTraceDesign.ColorToken.accent.opacity(0.25)
        }

        return isHovered ? LangoTraceDesign.ColorToken.hairline : .clear
    }
}
