import LangoTraceData

enum MacWorkspaceSection: CaseIterable, Hashable {
    case today
    case entries
    case practice
    case memory
    case importExport
    case settings

    var title: String {
        switch self {
        case .today:
            "今日"
        case .entries:
            "记录库"
        case .practice:
            "练习"
        case .memory:
            "词句记忆"
        case .importExport:
            "导入导出"
        case .settings:
            "设置"
        }
    }

    var description: String {
        switch self {
        case .today:
            "继续整理今天的生活记录和学习材料。当前为 Mac Local Mock 工作台。"
        case .entries:
            "浏览、选择和进入记录详情。真实搜索与批量管理后续接入。"
        case .practice:
            "从已有生活记录进入本地 mock 练习会话。"
        case .memory:
            "查看来自生活上下文的词句记忆和向量索引边界。"
        case .importExport:
            "预留批量导入、导出和附件整理位置，当前不可用。"
        case .settings:
            "查看语言空间、AI、同步、本地数据和隐私边界。"
        }
    }

    func subtitle(entriesCount: Int, memoryCount: Int) -> String {
        switch self {
        case .today:
            "继续当前记录"
        case .entries:
            "\(entriesCount) 条生活片段"
        case .practice:
            "Local Mock 会话"
        case .memory:
            "\(memoryCount) 条词句"
        case .importExport:
            "未接入文件能力"
        case .settings:
            "只读能力边界"
        }
    }
}

enum MacWorkspaceRoute: Equatable {
    case overview
    case entryDetail(String)
    case practice(String)
    case settings(SettingsCapability.Kind)
    case unavailable(String)
}

enum MacFooterAction {
    case languageSpace
    case aiProvider
    case sync
    case settings

    var section: MacWorkspaceSection {
        .settings
    }

    var route: MacWorkspaceRoute {
        switch self {
        case .languageSpace:
            .unavailable("language-space")
        case .aiProvider:
            .settings(.aiProvider)
        case .sync:
            .settings(.sync)
        case .settings:
            .overview
        }
    }
}

struct MacUnavailableContent {
    let content: UnavailableCapabilityContent

    init(kind: String) {
        switch kind {
        case "language-space":
            content = .languageSpace
        case "import-export":
            content = .importExport
        case "search":
            content = .search
        default:
            content = .generic
        }
    }
}
