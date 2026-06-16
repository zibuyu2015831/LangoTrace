import LangoTraceCore
import LangoTraceData

enum PadWorkspaceRoute: Equatable {
    case workspace
    case entryDetail(String)
    case practiceSentenceList(String)
    case practiceSentence(PracticeSessionRouteSeed)
    case reading
    case settingsList
    case settings(SettingsCapability.Kind)
    case memory
    case importExport
    case languageSpaceManagement

    var navigationTitleKey: String {
        switch self {
        case .workspace:
            "pad.route.workspace"
        case .entryDetail:
            "entryDetail.title"
        case .practiceSentenceList, .practiceSentence:
            "tab.practice"
        case .reading:
            "tab.reading"
        case .settingsList, .settings:
            "tab.settings"
        case .memory:
            "tab.memory"
        case .importExport:
            "mac.section.importExport"
        case .languageSpaceManagement:
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
            .languageSpaceManagement
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
