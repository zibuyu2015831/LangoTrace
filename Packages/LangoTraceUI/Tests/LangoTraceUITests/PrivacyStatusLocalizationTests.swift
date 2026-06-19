import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Privacy status localization")
struct PrivacyStatusLocalizationTests {
    private let requiredLanguages: Set<String> = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]

    @Test("Every AI provider status maps to catalog keys covering all interface languages")
    func aiProviderStatusKeysCoverAllInterfaceLanguages() throws {
        let strings = try catalogStrings()

        for status in AIProviderStatus.allCases {
            for key in [status.localizedTitleKey, status.localizedValueKey, status.localizedSummaryKey] {
                let localizations = try localizations(for: key, in: strings)
                #expect(
                    Set(localizations.keys) == requiredLanguages,
                    "\(key) must be localized for all interface languages"
                )
            }
        }
    }

    @Test("Every sync status maps to catalog keys covering all interface languages")
    func syncStatusKeysCoverAllInterfaceLanguages() throws {
        let strings = try catalogStrings()

        for status in SyncProviderStatus.allCases {
            for key in [status.localizedTitleKey, status.localizedValueKey, status.localizedSummaryKey] {
                let localizations = try localizations(for: key, in: strings)
                #expect(
                    Set(localizations.keys) == requiredLanguages,
                    "\(key) must be localized for all interface languages"
                )
            }
        }
    }

    @Test("Status cases keep distinct value and summary keys")
    func statusCasesKeepDistinctKeys() {
        #expect(Set(AIProviderStatus.allCases.map(\.localizedValueKey)).count == AIProviderStatus.allCases.count)
        #expect(Set(AIProviderStatus.allCases.map(\.localizedSummaryKey)).count == AIProviderStatus.allCases.count)
        #expect(Set(SyncProviderStatus.allCases.map(\.localizedValueKey)).count == SyncProviderStatus.allCases.count)
        #expect(Set(SyncProviderStatus.allCases.map(\.localizedSummaryKey)).count == SyncProviderStatus.allCases.count)
    }

    @Test("AI privacy summaries do not promise a request preview")
    func aiPrivacySummariesDoNotPromiseRequestPreview() throws {
        // Spec 005 §4.7: the implemented behavior is non-blocking confirmation
        // without a request preview, so the privacy copy must not overpromise.
        let strings = try catalogStrings()
        let forbiddenFragments = ["请求预览", "request preview", "preview"]

        for status in AIProviderStatus.allCases {
            let localizations = try localizations(for: status.localizedSummaryKey, in: strings)
            for (locale, value) in try localizedValues(localizations) {
                let matches = forbiddenFragments.filter { value.localizedCaseInsensitiveContains($0) }
                #expect(
                    matches.isEmpty,
                    "\(status.localizedSummaryKey) [\(locale)] overpromises: \(matches.joined(separator: ", "))"
                )
            }
        }
    }

    @Test("Help tooltip pattern keeps three positional arguments in every language")
    func helpTooltipPatternKeepsThreePositionalArguments() throws {
        let strings = try catalogStrings()
        let localizations = try localizations(for: "privacyStatus.help.format", in: strings)

        #expect(Set(localizations.keys) == requiredLanguages)
        for (locale, value) in try localizedValues(localizations) {
            for placeholder in ["%1$@", "%2$@", "%3$@"] {
                #expect(value.contains(placeholder), "privacyStatus.help.format [\(locale)] misses \(placeholder)")
            }
        }
    }

    @Test("Footer composes tooltip and copy from localized keys instead of hardcoded punctuation")
    func footerComposesTooltipFromLocalizedKeys() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceFooter.swift"), encoding: .utf8)

        #expect(source.contains("localizedString(\"privacyStatus.help.format\", title, value, summary)"))
        #expect(!source.contains("\\(title)："))
        #expect(source.contains("localizedString(aiStatus.localizedTitleKey)"))
        #expect(source.contains("localizedString(syncStatus.localizedSummaryKey)"))
        #expect(!source.contains("aiStatus.title"))
        #expect(!source.contains("syncStatus.summary,"))
    }

    @Test("Learning content accessibility labels join fragments through localized keys")
    func learningContentAccessibilityLabelsUseLocalizedJoins() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LearningContentComponents.swift"), encoding: .utf8)

        #expect(source.contains("\"entry.timeline.accessibilityLabel\""))
        #expect(source.contains("localizedText(\"accessibility.listSeparator\")"))
        #expect(!source.contains("Text(\"，\")"))
        #expect(!source.contains("，\\("))
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LangoTraceUI/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["strings"] as? [String: Any])
    }

    private func localizations(for key: String, in strings: [String: Any]) throws -> [String: Any] {
        let entry = try #require(strings[key] as? [String: Any], "missing catalog key \(key)")
        return try #require(entry["localizations"] as? [String: Any])
    }

    private func localizedValues(_ localizations: [String: Any]) throws -> [(String, String)] {
        try localizations.map { locale, value in
            let localization = try #require(value as? [String: Any])
            let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
            let localizedValue = try #require(stringUnit["value"] as? String)
            return (locale, localizedValue)
        }
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
