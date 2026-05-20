import Foundation
import Testing

@Suite("Onboarding level selector")
struct OnboardingLevelSelectorTests {
    @Test("Compact level selector is shared across Apple platforms")
    func compactLevelSelectorIsSharedAcrossApplePlatforms() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(!source.contains("OnboardingLevelSelectorStyle"))
        #expect(!source.contains("levelSelectorStyle"))
        #expect(!source.contains("userInterfaceIdiom"))
        #expect(!source.contains("segmentedLevelPicker"))
        #expect(!source.contains(".pickerStyle(.segmented)"))
        #expect(source.contains("compactLevelSelector"))
    }

    @Test("Compact level selector uses a scrollable localized list")
    func compactLevelSelectorUsesScrollableLocalizedList() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(source.contains("compactLevelSelector"))
        #expect(source.contains("ScrollView"))
        #expect(source.contains("LanguageLevel.allCases"))
        #expect(source.contains("onboarding.level.a1.title"))
        #expect(source.contains("onboarding.level.c2.description"))
        #expect(!source.contains("onboarding.level.question"))
        #expect(source.contains("levelSelectorApproxVisibleRows"))
        #expect(source.contains("@ScaledMetric"))
        #expect(source.contains("Button"))
        #expect(source.contains("accessibilityValue"))
        #expect(source.contains("accessibilityAddTraits"))
    }

    @Test("Onboarding level copy covers all declared interface languages")
    func onboardingLevelCopyCoversAllDeclaredInterfaceLanguages() throws {
        let catalog = try LocalizableCatalog.load(from: sourceFileURL(named: "Resources/Localizable.xcstrings"))
        let expectedLocales = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]
        let expectedKeys = [
            "onboarding.level.a1.title",
            "onboarding.level.a1.description",
            "onboarding.level.a2.title",
            "onboarding.level.a2.description",
            "onboarding.level.b1.title",
            "onboarding.level.b1.description",
            "onboarding.level.b2.title",
            "onboarding.level.b2.description",
            "onboarding.level.c1.title",
            "onboarding.level.c1.description",
            "onboarding.level.c2.title",
            "onboarding.level.c2.description",
        ]

        for key in expectedKeys {
            let localizations = try #require(catalog.strings[key], "Missing string catalog key: \(key)")

            for locale in expectedLocales {
                let value = try #require(
                    localizations[locale],
                    "Missing \(locale) localization for \(key)"
                )
                #expect(!value.isEmpty, "\(key) [\(locale)] must not be empty")
            }
        }

        #expect(catalog.strings["onboarding.level.title"]?["zh-Hans"] == "当前水平")
        #expect(catalog.strings["onboarding.subtitle"]?["zh-Hans"] == "创建一个语言空间，把生活变成学习材料。")
    }

    @Test("Onboarding level question does not hard-code English as target language")
    func onboardingLevelQuestionDoesNotHardCodeEnglishAsTargetLanguage() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(!source.contains("\"英语\""))
        #expect(!source.contains("\"English\""))
        #expect(!source.contains("localizedString(\"onboarding.level.question\""))
    }

    @Test("Local storage note is a button footnote instead of a form card")
    func localStorageNoteIsButtonFootnoteInsteadOfFormCard() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(!source.contains("privacyNote"))
        #expect(!source.contains("onboarding.privacy.localStorage"))
        #expect(!source.contains("onboarding.privacy.noExternalAI"))
        #expect(source.contains("localStorageFootnote"))
        #expect(source.contains("onboarding.privacy.footnote"))
        #expect(source.contains("createButtonContent"))
        #expect(source.contains("Button(action: onCreateLanguageSpace)"))
    }

    @Test("Local storage footnote copy covers all declared interface languages")
    func localStorageFootnoteCopyCoversAllDeclaredInterfaceLanguages() throws {
        let catalog = try LocalizableCatalog.load(from: sourceFileURL(named: "Resources/Localizable.xcstrings"))
        let expectedLocales = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]
        let localizations = try #require(
            catalog.strings["onboarding.privacy.footnote"],
            "Missing string catalog key: onboarding.privacy.footnote"
        )

        for locale in expectedLocales {
            let value = try #require(
                localizations[locale],
                "Missing \(locale) localization for onboarding.privacy.footnote"
            )
            #expect(!value.isEmpty, "onboarding.privacy.footnote [\(locale)] must not be empty")
        }

        #expect(catalog.strings["onboarding.privacy.footnote"]?["zh-Hans"] == "数据默认保存在本机，可在设置中查看与调整。")
    }

    @Test("iPad orientation-specific onboarding branches are ordered before shared wide layout")
    func padOrientationSpecificOnboardingBranchesAreOrderedBeforeSharedWideLayout() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        let landscapeIndex = try #require(source.range(of: "usesPadLandscapeOnboardingLayout(in: size)")?.lowerBound)
        let portraitIndex = try #require(source.range(of: "usesPadPortraitOnboardingLayout(in: size)")?.lowerBound)
        let wideIndex = try #require(source.range(of: "usesInlineWideOnboardingLayout(in: size)")?.lowerBound)
        let compactIndex = try #require(source.range(of: "compactOnboardingContentWithBottomAction")?.lowerBound)

        #expect(landscapeIndex < portraitIndex)
        #expect(portraitIndex < wideIndex)
        #expect(wideIndex < compactIndex)
        #expect(source.contains("padLandscapeOnboardingContent(size: size)"))
        #expect(source.contains("padPortraitOnboardingContent(size: size)"))
        #expect(source.contains("#if os(iOS)"))
        #expect(!source.contains("userInterfaceIdiom"))
    }

    @Test("iPad onboarding orientation predicates use geometry thresholds")
    func padOnboardingOrientationPredicatesUseGeometryThresholds() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(source.contains("private func usesPadLandscapeOnboardingLayout(in size: CGSize) -> Bool"))
        #expect(source.contains("size.width >= 980"))
        #expect(source.contains("size.height >= 680"))
        #expect(source.contains("size.width > size.height"))
        #expect(source.contains("private func usesPadPortraitOnboardingLayout(in size: CGSize) -> Bool"))
        #expect(source.contains("size.width >= 760"))
        #expect(source.contains("size.height >= 900"))
        #expect(source.contains("size.height > size.width"))
    }

    @Test("iPad onboarding layouts use shared value summary and four visible level rows")
    func padOnboardingLayoutsUseSharedValueSummaryAndFourVisibleLevelRows() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(source.contains("private let padLevelSelectorApproxVisibleRows: CGFloat = 4"))
        #expect(source.contains("languageForm(levelVisibleRows: padLevelSelectorApproxVisibleRows)"))
        #expect(source.contains("compactLevelSelector(visibleRows: levelVisibleRows)"))
        #expect(source.contains("levelSelectorMaxHeight(visibleRows: visibleRows)"))
        #expect(source.contains("padOnboardingValueItems"))
        #expect(source.contains("padPortraitValueStrip"))
        #expect(source.contains("padOnboardingValueList"))
        #expect(source.contains("onboarding.value.trace.title"))
        #expect(!source.contains("onboarding.value.growth"))
    }

    @Test("iPad onboarding value copy covers all declared interface languages")
    func padOnboardingValueCopyCoversAllDeclaredInterfaceLanguages() throws {
        let catalog = try LocalizableCatalog.load(from: sourceFileURL(named: "Resources/Localizable.xcstrings"))
        let expectedLocales = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]
        let expectedKeys = [
            "onboarding.value.record.title",
            "onboarding.value.record.subtitle",
            "onboarding.value.practice.title",
            "onboarding.value.practice.subtitle",
            "onboarding.value.trace.title",
            "onboarding.value.trace.subtitle",
        ]

        for key in expectedKeys {
            let localizations = try #require(catalog.strings[key], "Missing string catalog key: \(key)")

            for locale in expectedLocales {
                let value = try #require(
                    localizations[locale],
                    "Missing \(locale) localization for \(key)"
                )
                #expect(!value.isEmpty, "\(key) [\(locale)] must not be empty")
            }
        }

        #expect(catalog.strings["onboarding.value.record.title"]?["zh-Hans"] == "记录生活")
        #expect(catalog.strings["onboarding.value.record.subtitle"]?["zh-Hans"] == "照片、声音与文字")
        #expect(catalog.strings["onboarding.value.practice.title"]?["zh-Hans"] == "练习表达")
        #expect(catalog.strings["onboarding.value.practice.subtitle"]?["zh-Hans"] == "在真实语境中学习")
        #expect(catalog.strings["onboarding.value.trace.title"]?["zh-Hans"] == "留下语迹")
        #expect(catalog.strings["onboarding.value.trace.subtitle"]?["zh-Hans"] == "看见自己的语言成长")
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

private struct LocalizableCatalog {
    let strings: [String: [String: String]]

    static func load(from url: URL) throws -> LocalizableCatalog {
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rawStrings = try #require(root["strings"] as? [String: Any])

        let strings = rawStrings.reduce(into: [String: [String: String]]()) { result, element in
            guard
                let entry = element.value as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                return
            }

            result[element.key] = localizations.reduce(into: [String: String]()) { values, localization in
                guard
                    let localizationEntry = localization.value as? [String: Any],
                    let unit = localizationEntry["stringUnit"] as? [String: Any],
                    let value = unit["value"] as? String
                else {
                    return
                }

                values[localization.key] = value
            }
        }

        return LocalizableCatalog(strings: strings)
    }
}
