import LangoTraceData

enum MacWorkspaceSection: CaseIterable, Hashable {
    case today
    case entries
    case practice
    case memory
    case importExport
    case settings

    var titleKey: String {
        switch self {
        case .today:
            "tab.today"
        case .entries:
            "mac.section.entries"
        case .practice:
            "tab.practice"
        case .memory:
            "mac.section.memory"
        case .importExport:
            "mac.section.importExport"
        case .settings:
            "tab.settings"
        }
    }

    var descriptionKey: String {
        switch self {
        case .today:
            "mac.section.today.description"
        case .entries:
            "mac.section.entries.description"
        case .practice:
            "mac.section.practice.description"
        case .memory:
            "mac.section.memory.description"
        case .importExport:
            "mac.section.importExport.description"
        case .settings:
            "mac.section.settings.description"
        }
    }

    func subtitle(entriesCount: Int, memoryCount: Int) -> String {
        switch self {
        case .today:
            localizedString("mac.section.today.subtitle")
        case .entries:
            localizedString("mac.section.entries.subtitle", entriesCount)
        case .practice:
            localizedString("mac.section.practice.subtitle")
        case .memory:
            localizedString("mac.section.memory.subtitle", memoryCount)
        case .importExport:
            localizedString("mac.section.importExport.subtitle")
        case .settings:
            localizedString("mac.section.settings.subtitle")
        }
    }
}

enum MacWorkspaceRoute: Equatable {
    case overview
    case entryDetail(String)
    case practice(String)
    case settings(SettingsCapability.Kind)
    case languageSpaceSummary
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
            .languageSpaceSummary
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
        case "import-export":
            content = .importExport
        case "search":
            content = .search
        default:
            content = .generic
        }
    }
}
