import LangoTraceData

extension EntryPracticeStatus {
    var displayLabel: String {
        switch self {
        case .notStarted:
            String(localized: "entry.practiceStatus.notStarted", bundle: .module)
        case let .practiced(count):
            String(format: String(localized: "entry.practiceStatus.practiced", bundle: .module), count)
        case .memorized:
            String(localized: "entry.practiceStatus.memorized", bundle: .module)
        }
    }
}

extension LearningEntry {
    var displayTitle: String {
        title.isEmpty
            ? String(localized: "entry.defaultTitle", bundle: .module)
            : title
    }

    var displayScene: String {
        scene.isEmpty
            ? String(localized: "entry.defaultScene", bundle: .module)
            : scene
    }
}
