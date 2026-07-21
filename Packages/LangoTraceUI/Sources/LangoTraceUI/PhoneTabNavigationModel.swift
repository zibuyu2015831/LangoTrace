import LangoTraceCore
import Observation

@Observable
final class PhoneTabNavigationModel {
    var selectedTab: PhoneRootTab = .entries
    var entriesPath: [PhoneRoute] = []
    var readingPath: [PhoneRoute] = []
    var practicePath: [PhoneRoute] = []
    var memoryPath: [PhoneRoute] = []

    func path(for tab: PhoneRootTab) -> [PhoneRoute] {
        switch tab {
        case .entries: entriesPath
        case .reading: readingPath
        case .practice: practicePath
        case .memory: memoryPath
        }
    }

    func push(_ route: PhoneRoute, on tab: PhoneRootTab) {
        switch tab {
        case .entries: entriesPath.append(route)
        case .reading: readingPath.append(route)
        case .practice: practicePath.append(route)
        case .memory: memoryPath.append(route)
        }
    }

    func replaceCurrentRoute(with route: PhoneRoute, on tab: PhoneRootTab) {
        switch tab {
        case .entries:
            if entriesPath.isEmpty {
                entriesPath.append(route)
            } else {
                entriesPath[entriesPath.count - 1] = route
            }
        case .reading:
            if readingPath.isEmpty {
                readingPath.append(route)
            } else {
                readingPath[readingPath.count - 1] = route
            }
        case .practice:
            if practicePath.isEmpty {
                practicePath.append(route)
            } else {
                practicePath[practicePath.count - 1] = route
            }
        case .memory:
            if memoryPath.isEmpty {
                memoryPath.append(route)
            } else {
                memoryPath[memoryPath.count - 1] = route
            }
        }
    }
}
