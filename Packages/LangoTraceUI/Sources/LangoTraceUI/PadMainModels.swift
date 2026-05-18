import LangoTraceData

enum PadFilter: String, CaseIterable, Equatable {
    case all
    case photoWriting
    case needsPractice
    case memorized

    var titleKey: String {
        switch self {
        case .all:
            "pad.filter.all"
        case .photoWriting:
            "entrySource.photoWriting"
        case .needsPractice:
            "pad.filter.needsPractice"
        case .memorized:
            "pad.filter.memorized"
        }
    }

    func includes(entry: LearningEntry, memoryItems: [MemoryItem]) -> Bool {
        switch self {
        case .all:
            true
        case .photoWriting:
            entry.source == .photoWriting
        case .needsPractice:
            !memoryItems.contains { $0.entryID == entry.id }
        case .memorized:
            memoryItems.contains { $0.entryID == entry.id }
        }
    }
}

enum PadWorkspaceRoute: Equatable {
    case workspace
    case entryDetail(String)
    case practice(String)
    case settingsList
    case settings(SettingsCapability.Kind)
    case memory
    case importExport
    case languageSpaceSummary

    var navigationTitleKey: String {
        switch self {
        case .workspace:
            "pad.route.workspace"
        case .entryDetail:
            "entryDetail.title"
        case .practice:
            "tab.practice"
        case .settingsList, .settings:
            "tab.settings"
        case .memory:
            "tab.memory"
        case .importExport:
            "mac.section.importExport"
        case .languageSpaceSummary:
            "settings.languageSpace.title"
        }
    }
}

enum PadFooterAction {
    case languageSpace
    case aiProvider
    case sync
    case settings

    var route: PadWorkspaceRoute {
        switch self {
        case .languageSpace:
            .languageSpaceSummary
        case .aiProvider:
            .settings(.aiProvider)
        case .sync:
            .settings(.sync)
        case .settings:
            .settingsList
        }
    }
}

enum PadSheet: Identifiable {
    case entryEditor
    case unavailableSearch

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        case .unavailableSearch:
            "unavailable-search"
        }
    }
}
