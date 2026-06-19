import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Entry reading localization")
struct EntryReadingLocalizationTests {
    private let requiredLanguages: Set<String> = ["en", "zh-Hans"]

    private let newKeys: [String] = [
        "entry.reading.title",
        "entry.reading.open",
        "entry.reading.fontSize.decrease",
        "entry.reading.fontSize.increase",
        "entry.reading.reveal.hint",
        "entry.reading.empty",
        "entry.reading.playAll",
        "entry.reading.playAll.stop",
    ]

    @Test("Every reading key ships non-empty en and zh-Hans values")
    func readingKeysShipBaseLanguages() throws {
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

    @Test("Reading keys are distinct")
    func readingKeysAreDistinct() {
        #expect(Set(newKeys).count == newKeys.count)
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EntryReading/
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
