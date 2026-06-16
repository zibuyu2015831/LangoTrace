import LangoTraceCore
import LangoTraceData

enum MacWorkspaceSection: CaseIterable, Hashable {
    case today
    case entries
    case reading
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
        case .reading:
            "tab.reading"
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
        case .reading:
            "reading.library.subtitle"
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

    func subtitle(counts: EntryTimelineCounts, memoryCount: Int) -> String {
        switch self {
        case .today:
            localizedString("mac.section.today.subtitle", counts.today)
        case .entries:
            localizedString("mac.section.entries.subtitle", counts.total)
        case .reading:
            localizedString("reading.library.subtitle")
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
    case reading
    case practiceSentenceList(String)
    case practiceSentence(PracticeSessionRouteSeed)
    case settings(SettingsCapability.Kind)
    case languageSpaceManagement
    case unavailable(String)

    var usesDedicatedMainScrolling: Bool {
        switch self {
        case .practiceSentenceList, .practiceSentence, .languageSpaceManagement,
             .entryDetail, .reading:
            true
        case .overview, .settings, .unavailable:
            false
        }
    }
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
            .languageSpaceManagement
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
