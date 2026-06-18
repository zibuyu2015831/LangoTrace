import LangoTraceData

/// Storage key for the bilingual reading font scale preference. This is a purely
/// presentational, non-sensitive UI preference (not synced, loss is acceptable), so it
/// lives in `UserDefaults`/`@AppStorage` rather than the GRDB config table. Defined once
/// here so all three platforms read and write the same key.
enum EntryReadingPreferenceKey {
    static let fontScale = "entryReading.fontScale"
}

/// User-adjustable reading font scale for the bilingual reading page. Pure value type so
/// the increment/clamp logic is unit-testable without a running UI.
enum EntryReadingFontScale: Int, CaseIterable, Equatable {
    case small = 0
    case standard = 1
    case large = 2
    case extraLarge = 3

    static let `default` = EntryReadingFontScale.standard

    /// Multiplier applied to the base reading font sizes.
    var multiplier: Double {
        switch self {
        case .small: 0.9
        case .standard: 1.0
        case .large: 1.18
        case .extraLarge: 1.4
        }
    }

    var canIncrease: Bool {
        rawValue < EntryReadingFontScale.allCases.count - 1
    }

    var canDecrease: Bool {
        rawValue > 0
    }

    func increased() -> EntryReadingFontScale {
        EntryReadingFontScale(rawValue: rawValue + 1) ?? self
    }

    func decreased() -> EntryReadingFontScale {
        EntryReadingFontScale(rawValue: rawValue - 1) ?? self
    }
}

/// Tracks which sentences currently reveal their native-language translation and note.
/// Pure value type, unit-testable; the reading view drives it from `@State`.
struct EntryReadingRevealState: Equatable {
    private(set) var revealedSentenceIDs: Set<String>

    init(revealedSentenceIDs: Set<String> = []) {
        self.revealedSentenceIDs = revealedSentenceIDs
    }

    func isRevealed(_ id: String) -> Bool {
        revealedSentenceIDs.contains(id)
    }

    var isAllHidden: Bool {
        revealedSentenceIDs.isEmpty
    }

    mutating func toggle(_ id: String) {
        if revealedSentenceIDs.contains(id) {
            revealedSentenceIDs.remove(id)
        } else {
            revealedSentenceIDs.insert(id)
        }
    }

    mutating func revealAll(_ ids: [String]) {
        revealedSentenceIDs.formUnion(ids)
    }

    mutating func hideAll() {
        revealedSentenceIDs.removeAll()
    }
}

/// Presentation model for the bilingual reading page, derived from the live
/// `LearningRendering`. The reading page is a real-time view of the current material (it
/// is not snapshotted into the route), so callers build this from the store's live
/// rendering. When per-sentence analysis is missing/stale, the full target text remains
/// readable so the page is never blank.
struct EntryReadingPresentation: Equatable {
    struct Sentence: Equatable, Identifiable {
        let id: String
        let target: String
        let translation: String
        let note: String
    }

    let fullTargetText: String
    let sentences: [Sentence]

    var hasSentences: Bool {
        !sentences.isEmpty
    }

    var showsFullTextFallback: Bool {
        sentences.isEmpty && !fullTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isEmpty: Bool {
        sentences.isEmpty && fullTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func make(from rendering: LearningRendering?) -> EntryReadingPresentation {
        guard let rendering else {
            return EntryReadingPresentation(fullTargetText: "", sentences: [])
        }
        let sentences = rendering.sentences.map { sentence in
            Sentence(
                id: sentence.id,
                target: sentence.targetText,
                translation: sentence.translation,
                note: sentence.note
            )
        }
        return EntryReadingPresentation(fullTargetText: rendering.targetText, sentences: sentences)
    }
}
