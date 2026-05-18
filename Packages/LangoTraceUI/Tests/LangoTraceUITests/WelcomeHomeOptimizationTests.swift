import Foundation
import Testing

@Suite("Welcome home optimization")
struct WelcomeHomeOptimizationTests {
    @Test("Welcome view uses value-first copy, optional AI, setup CTA, and preview card")
    func welcomeViewUsesOptimizedHomeCopyKeys() throws {
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

        for expectedSnippet in [
            #"localizedText("welcome.valueTitle")"#,
            #"localizedText("welcome.valueSubtitle")"#,
            #"localizedText("app.badge.aiOptional")"#,
            #"localizedText("welcome.tracePreview.title")"#,
            #"localizedText("welcome.tracePreview.expression")"#,
            #"localizedText("welcome.cta.startSetup")"#,
            #"localizedText("welcome.setupTimeLocalNote")"#,
        ] {
            #expect(source.contains(expectedSnippet), "WelcomeView is missing \(expectedSnippet)")
        }

        for retiredSnippet in [
            "ProductIdentity.displayName",
            "ProductIdentity.chineseSlogan",
            "ProductIdentity.englishSlogan",
            #"localizedText("app.badge.aiNotConfigured")"#,
            #"localizedText("common.continue")"#,
        ] {
            #expect(!source.contains(retiredSnippet), "WelcomeView still uses retired snippet \(retiredSnippet)")
        }
    }

    @Test("Mobile and iPad welcome layouts keep optimized content in the first viewport")
    func welcomeLayoutsKeepOptimizedContentInFirstViewport() throws {
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

        #expect(!source.contains("Spacer(minLength:"))
        #expect(source.contains("private func compactVerticalSpacing(in size: CGSize) -> CGFloat"))
        #expect(source.contains("private func compactContentTopPadding(in size: CGSize) -> CGFloat"))
        #expect(source.contains("private func wideContentTopPadding(in size: CGSize) -> CGFloat"))
        #expect(source.contains(".frame(maxWidth: 1120, minHeight: size.height, alignment: .top)"))
        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .top)"))
    }

    @Test("Welcome optimization copy exists for every interface language")
    func welcomeOptimizationCopyExistsForEveryInterfaceLanguage() throws {
        let catalog = try WelcomeStringCatalog.load(from: sourceFileURL(named: "Resources/Localizable.xcstrings"))
        let requiredKeys = [
            "app.badge.aiOptional",
            "welcome.valueTitle",
            "welcome.valueSubtitle",
            "welcome.cta.startSetup",
            "welcome.setupTimeLocalNote",
            "welcome.tracePreview.title",
            "welcome.tracePreview.scene",
            "welcome.tracePreview.body",
            "welcome.tracePreview.vocabularyTitle",
            "welcome.tracePreview.vocabulary",
            "welcome.tracePreview.expressionTitle",
            "welcome.tracePreview.expression",
            "welcome.tracePreview.practiceTitle",
            "welcome.tracePreview.practice",
            "welcome.tracePreview.compactPractice",
        ]
        let requiredLocales = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]

        for key in requiredKeys {
            let entry = try #require(catalog.strings[key], "Missing catalog key \(key)")
            for locale in requiredLocales {
                let value = entry.localizedValues[locale]
                #expect(value?.isEmpty == false, "Missing \(locale) localization for \(key)")
            }
        }
    }

    private func sourceFileURL(named relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(relativePath)
    }
}

private struct WelcomeStringCatalog: Decodable {
    let strings: [String: WelcomeStringCatalogEntry]

    static func load(from url: URL) throws -> WelcomeStringCatalog {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WelcomeStringCatalog.self, from: data)
    }
}

private struct WelcomeStringCatalogEntry: Decodable {
    let localizations: [String: WelcomeStringCatalogLocalization]?

    var localizedValues: [String: String] {
        (localizations ?? [:]).reduce(into: [String: String]()) { result, element in
            result[element.key] = element.value.stringUnit?.value
        }
    }
}

private struct WelcomeStringCatalogLocalization: Decodable {
    let stringUnit: WelcomeStringCatalogStringUnit?
}

private struct WelcomeStringCatalogStringUnit: Decodable {
    let value: String
}
