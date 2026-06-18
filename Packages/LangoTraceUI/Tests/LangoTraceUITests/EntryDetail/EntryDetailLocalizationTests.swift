import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Entry detail localization")
struct EntryDetailLocalizationTests {
    /// Entry-detail copy follows the surrounding convention of shipping the source language
    /// (en) plus Simplified Chinese, relying on en fallback for other interface languages.
    private let requiredLanguages: Set<String> = ["en", "zh-Hans"]

    private let newKeys: [String] = [
        "entry.detail.expand",
        "entry.detail.collapse",
        "entry.detail.learningText.regenerateMenu",
        "entry.detail.learningText.regenerateMenu.translate",
        "entry.detail.learningText.regenerateMenu.reanalyze",
        "entry.detail.learningText.regenerate.confirmTitle",
        "entry.detail.learningText.regenerate.confirmMessage",
        "entry.detail.learningText.regenerate.confirm",
    ]

    @Test("Every new entry-detail key ships non-empty en and zh-Hans values")
    func newKeysShipBaseLanguages() throws {
        let strings = try catalogStrings()

        for key in newKeys {
            let localizations = try localizations(for: key, in: strings)
            #expect(
                requiredLanguages.isSubset(of: Set(localizations.keys)),
                "\(key) must ship at least en and zh-Hans"
            )
            for language in requiredLanguages {
                let localization = try #require(localizations[language] as? [String: Any], "\(key) missing \(language)")
                let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
                let value = try #require(stringUnit["value"] as? String)
                #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(key) [\(language)] is empty")
            }
        }
    }

    @Test("New entry-detail keys are distinct")
    func newKeysAreDistinct() {
        #expect(Set(newKeys).count == newKeys.count)
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EntryDetail/
            .deletingLastPathComponent() // LangoTraceUITests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // LangoTraceUI/ (package root)
            .appendingPathComponent("Sources/LangoTraceUI/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["strings"] as? [String: Any])
    }

    private func localizations(for key: String, in strings: [String: Any]) throws -> [String: Any] {
        let entry = try #require(strings[key] as? [String: Any], "missing catalog key \(key)")
        return try #require(entry["localizations"] as? [String: Any])
    }
}
