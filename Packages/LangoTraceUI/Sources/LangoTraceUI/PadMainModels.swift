import LangoTraceData

enum PadFilter: String, CaseIterable, Equatable {
    case all
    case photoWriting
    case needsPractice
    case memorized

    var title: String {
        switch self {
        case .all:
            "全部记录"
        case .photoWriting:
            "照片写作"
        case .needsPractice:
            "待练习"
        case .memorized:
            "已入记忆"
        }
    }

    func includes(entry: LearningEntry, memoryItems: [MemoryItem]) -> Bool {
        switch self {
        case .all:
            true
        case .photoWriting:
            entry.source == .photoWriting
        case .needsPractice:
            entry.practiceSummary.contains("待") || entry.practiceSummary.contains("练习")
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
    case languageSpaceUnavailable

    var navigationTitle: String {
        switch self {
        case .workspace:
            "工作台"
        case .entryDetail:
            "记录详情"
        case .practice:
            "练习"
        case .settingsList, .settings:
            "设置"
        case .memory:
            "记忆"
        case .importExport:
            "导入导出"
        case .languageSpaceUnavailable:
            "语言空间"
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
            .languageSpaceUnavailable
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
