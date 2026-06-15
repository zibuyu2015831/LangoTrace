import Foundation

public struct ReadingDictionaryEntry: Equatable, Sendable {
    public var headword: String
    public private(set) var normalizedHeadword: String
    public var languageCode: String
    public var definition: String

    public init(headword: String, languageCode: String, definition: String) {
        self.headword = headword
        self.languageCode = languageCode
        self.definition = definition
        normalizedHeadword = Self.normalize(headword, languageCode: languageCode)
    }

    /// Single source of truth for lookup-key normalization. The init derives
    /// `normalizedHeadword` from `headword` with this, and `exactLookup`
    /// normalizes the query the same way, so caller-supplied normalization can
    /// no longer drift from what the index actually keys on.
    static func normalize(_ value: String, languageCode: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: languageCode))
            .lowercased()
    }
}

public struct ReadingDictionaryLookupIndex: Sendable {
    private var entriesByKey: [String: [ReadingDictionaryEntry]]

    public init(entries: [ReadingDictionaryEntry]) {
        entriesByKey = Dictionary(grouping: entries) { entry in
            Self.key(normalized: entry.normalizedHeadword, languageCode: entry.languageCode)
        }
    }

    public func exactLookup(_ query: String, languageCode: String) -> [ReadingDictionaryEntry] {
        let normalized = ReadingDictionaryEntry.normalize(query, languageCode: languageCode)
        return entriesByKey[Self.key(normalized: normalized, languageCode: languageCode)] ?? []
    }

    private static func key(normalized: String, languageCode: String) -> String {
        "\(languageCode.lowercased())|\(normalized.lowercased())"
    }
}
