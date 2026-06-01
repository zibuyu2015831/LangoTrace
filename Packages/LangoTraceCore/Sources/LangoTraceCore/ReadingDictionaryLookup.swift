import Foundation

public struct ReadingDictionaryEntry: Equatable, Sendable {
    public var headword: String
    public var normalizedHeadword: String
    public var languageCode: String
    public var definition: String

    public init(headword: String, normalizedHeadword: String, languageCode: String, definition: String) {
        self.headword = headword
        self.normalizedHeadword = normalizedHeadword
        self.languageCode = languageCode
        self.definition = definition
    }
}

public struct ReadingDictionaryLookupIndex: Sendable {
    private var entriesByKey: [String: [ReadingDictionaryEntry]]

    public init(entries: [ReadingDictionaryEntry]) {
        self.entriesByKey = Dictionary(grouping: entries) { entry in
            Self.key(normalized: entry.normalizedHeadword, languageCode: entry.languageCode)
        }
    }

    public func exactLookup(_ query: String, languageCode: String) -> [ReadingDictionaryEntry] {
        let normalized = query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: languageCode))
            .lowercased()
        return entriesByKey[Self.key(normalized: normalized, languageCode: languageCode)] ?? []
    }

    private static func key(normalized: String, languageCode: String) -> String {
        "\(languageCode.lowercased())|\(normalized.lowercased())"
    }
}
