import Foundation
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Three-platform presentation copy")
struct ThreePlatformPresentationCopyTests {
    @Test("Visible catalog copy avoids engineering-stage wording")
    func visibleCatalogCopyAvoidsEngineeringStageWording() throws {
        let catalog = try StringCatalog.load(from: sourceFileURL(named: "Resources/Localizable.xcstrings"))
        let checkedPrefixes = [
            "capabilityStatus.",
            "entry.",
            "mac.",
            "memory.",
            "pad.",
            "phone.",
            "practice.",
            "requestPreview.",
            "settings.",
            "unavailable.",
        ]
        let skippedKeys = Set([
            "settings.interfaceLanguage.systemBoundary",
        ])

        let checkedEntries = catalog.strings.filter { key, _ in
            checkedPrefixes.contains(where: key.hasPrefix) && !skippedKeys.contains(key)
        }

        for (key, entry) in checkedEntries {
            for (locale, value) in entry.localizedValues {
                let matches = forbiddenPresentationTerms.filter { term in
                    value.localizedCaseInsensitiveContains(term)
                }

                #expect(
                    matches.isEmpty,
                    "\(key) [\(locale)] exposes engineering wording: \(matches.joined(separator: ", "))"
                )
            }
        }
    }

    @Test("Main platform SwiftUI surfaces avoid hard-coded engineering-stage wording")
    func mainPlatformSwiftUISurfacesAvoidHardCodedEngineeringStageWording() throws {
        for fileName in [
            "PhoneMainSections.swift",
            "PhoneMainSupportingViews.swift",
            "PadMainSections.swift",
            "MacMainView.swift",
            "MacWorkspaceContentView.swift",
            "LearningContentComponents.swift",
            "PracticePromptCard.swift",
            "PracticeSessionViews.swift",
            "LanguageSpaceSwitcherSheet.swift",
            "LangoTraceSettingsSceneView.swift",
        ] {
            let source = try String(contentsOf: sourceFileURL(named: fileName), encoding: .utf8)
            let matches = forbiddenHardCodedTerms.filter { term in
                source.localizedCaseInsensitiveContains(term)
            }

            #expect(
                matches.isEmpty,
                "\(fileName) exposes hard-coded engineering wording: \(matches.joined(separator: ", "))"
            )
        }
    }

    @Test("Sample learning content avoids engineering-stage wording")
    func sampleLearningContentAvoidsEngineeringStageWording() {
        let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
        let entry = repository.entries(for: "en")[0]
        let rendering = repository.rendering(for: entry.id)
        let session = repository.practiceSession(for: entry.id)
        let entryStrings = repository.entries(for: "en").flatMap { entry in
            [
                entry.title,
                entry.body,
                entry.practiceStatus.displayLabel,
            ]
        }
        let memoryStrings = repository.memoryItems(for: "en").flatMap { item in
            [
                item.text,
                item.note,
            ]
        }
        let renderingStrings = [
            rendering?.providerLabel,
            rendering?.targetText,
            rendering?.promptLabel,
            session?.providerLabel,
        ].compactMap(\.self)
        let sentenceStrings = (rendering?.sentences ?? []).flatMap { sentence in
            [
                sentence.translation,
                sentence.targetText,
                sentence.note,
            ]
        }
        let visibleStrings = entryStrings + memoryStrings + renderingStrings + sentenceStrings

        for value in visibleStrings {
            let matches = forbiddenPresentationTerms.filter { term in
                value.localizedCaseInsensitiveContains(term)
            }

            #expect(
                matches.isEmpty,
                "Sample content exposes engineering wording: \(matches.joined(separator: ", ")) in \(value)"
            )
        }
    }

    @Test("Practice session interaction keys are localized")
    func practiceSessionInteractionKeysAreLocalized() throws {
        let catalog = try StringCatalog.load(from: sourceFileURL(named: "Resources/Localizable.xcstrings"))
        let requiredKeys = [
            "practice.navigation.previous",
            "practice.navigation.next",
            "practice.navigation.position",
            "practice.recording.recordAgain",
            "practice.prompt.translation.title",
            "practice.prompt.translation.expand",
            "practice.prompt.translation.collapse",
            "practice.prompt.translation.toggle.hint",
            "practice.prompt.explanation.expand",
            "practice.prompt.explanation.collapse",
            "practice.prompt.explanation.toggle.hint",
        ]

        for key in requiredKeys {
            let localizedValues = catalog.strings[key]?.localizedValues ?? []
            let locales = Set(localizedValues.map(\.locale))

            #expect(locales.contains("en"), "\(key) is missing English copy")
            #expect(locales.contains("zh-Hans"), "\(key) is missing Simplified Chinese copy")
            for value in localizedValues.map(\.value) {
                #expect(!value.isEmpty, "\(key) has empty localized copy")
                #expect(value != key, "\(key) exposes its raw localization key")
            }
        }
    }

    private var forbiddenPresentationTerms: [String] {
        [
            "mock",
            "SQLite",
            "GRDB",
            "Keychain",
            "API Key",
            "local database",
            "sample content",
            "not connected",
            "not implemented",
            "not saved yet",
            "read-only",
            "repository",
            "unavailable",
            "in-memory",
            "Prompt",
            "provider-backed",
            "内存",
            "本地示例",
            "真实接入",
            "尚未接入",
            "尚不能",
            "尚未实现",
            "未接入",
            "未支持",
            "未配置真实",
            "真实数据库",
            "真实配置",
            "本地数据库",
            "内存 mock",
            "页面闭环",
            "不会查询真实数据库",
            "当前边界",
            "后续接入条件",
            "不会发生",
            "本机预览",
            "Current Boundary",
            "Next Requirement",
            "Will Not Happen",
            "What Will Not Happen",
            "Required Before Connecting",
            "On-device preview",
        ]
    }

    private var forbiddenHardCodedTerms: [String] {
        [
            "Local Mock",
            "SQLite",
            "GRDB",
            "in-memory",
            "repository",
            "尚未接入",
            "尚不能",
            "尚未实现",
            "未接入",
            "未支持",
            "真实数据库",
            "真实配置",
            "内存",
            "内存 mock",
            "页面闭环",
            "不会查询真实数据库",
        ]
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

private struct StringCatalog: Decodable {
    let strings: [String: StringCatalogEntry]

    static func load(from url: URL) throws -> StringCatalog {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StringCatalog.self, from: data)
    }
}

private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?

    var localizedValues: [(locale: String, value: String)] {
        (localizations ?? [:])
            .compactMap { locale, localization in
                guard let value = localization.stringUnit?.value else {
                    return nil
                }

                return (locale, value)
            }
    }
}

private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit?
}

private struct StringCatalogStringUnit: Decodable {
    let value: String
}
