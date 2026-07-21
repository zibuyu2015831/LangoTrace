import LangoTraceCore
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
        EntrySceneDisplay.label(forStoredScene: scene)
    }
}

/// Projects a stored `entries.scene` value to display text.
///
/// Three states: preset slugs map to localized labels; free-form text (for
/// example imported via the E10 plaintext package) is user content and stays
/// verbatim per spec/006; an empty value falls back to the default label.
enum EntrySceneDisplay {
    static func label(forStoredScene scene: String) -> String {
        if scene.isEmpty {
            return String(localized: "entry.defaultScene", bundle: .module)
        }
        if let preset = EntryScenePreset(rawValue: scene) {
            return label(for: preset)
        }
        return scene
    }

    static func label(for preset: EntryScenePreset) -> String {
        switch preset {
        case .daily:
            String(localized: "entryScene.daily", bundle: .module)
        case .work:
            String(localized: "entryScene.work", bundle: .module)
        case .travel:
            String(localized: "entryScene.travel", bundle: .module)
        case .mood:
            String(localized: "entryScene.mood", bundle: .module)
        case .meeting:
            String(localized: "entryScene.meeting", bundle: .module)
        case .email:
            String(localized: "entryScene.email", bundle: .module)
        }
    }
}
