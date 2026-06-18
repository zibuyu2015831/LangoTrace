import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Page closure state")
struct PageClosureStateTests {
    @Test("Timeline filters include the expected mock records")
    func timelineFiltersIncludeExpectedRecords() {
        let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
        let entries = repository.entries(for: "en")

        #expect(entries.count(where: { EntryTimelineFilter.all.includes(entry: $0, hasMaterialWithoutRecording: false, hasPhotoAttachment: false) }) == entries.count)
        #expect(entries.filter { EntryTimelineFilter.photo.includes(entry: $0, hasMaterialWithoutRecording: false, hasPhotoAttachment: false) }
            .allSatisfy { $0.source == .photoWriting })
        #expect(entries.filter { EntryTimelineFilter.settled.includes(entry: $0, hasMaterialWithoutRecording: false, hasPhotoAttachment: false) }
            .isEmpty)
    }

    @Test("Pad footer actions route to visible pages")
    func padFooterActionsRouteToVisiblePages() {
        #expect(PadFooterAction.languageSpace.route == .languageSpaceManagement)
        #expect(PadFooterAction.aiProvider.route == .settings(SettingsCapability.Kind.aiProvider))
        #expect(PadFooterAction.sync.route == .settings(SettingsCapability.Kind.sync))
        #expect(PadFooterAction.settings.route == .settingsList)
    }

    @Test("Pad workspace pages include iPad-only closure pages")
    func padWorkspacePagesIncludeIPadOnlyClosurePages() {
        #expect(PadWorkspaceRoute.settingsList.navigationTitleKey == "tab.settings")
        #expect(PadWorkspaceRoute.memory.navigationTitleKey == "tab.memory")
        #expect(PadWorkspaceRoute.importExport.navigationTitleKey == "mac.section.importExport")
        #expect(PadWorkspaceRoute.languageSpaceManagement.navigationTitleKey == "settings.languageSpace.title")
    }

    @Test("Pad learning panel switches content by workspace route")
    func padLearningPanelSwitchesContentByWorkspaceRoute() throws {
        let mainSource = try String(contentsOf: sourceFileURL(named: "PadMainView.swift"), encoding: .utf8)
        let sectionsSource = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let learningPanelSource = try String(
            contentsOf: sourceFileURL(named: "PadLearningPanelView.swift"),
            encoding: .utf8
        )

        #expect(mainSource.contains("route: route"))
        #expect(mainSource.contains("PadLearningPanelView"))
        #expect(sectionsSource.contains("PadWorkspaceContentView"))
        #expect(learningPanelSource.contains("let route: PadWorkspaceRoute"))
        #expect(learningPanelSource.contains("switch route"))
        #expect(learningPanelSource.contains("case .workspace, .entryDetail, .practice"))
        #expect(learningPanelSource.contains("case .settingsList, .settings"))
        #expect(learningPanelSource.contains("settingsContextContent"))
        #expect(learningPanelSource.contains("case .memory"))
        #expect(learningPanelSource.contains("case .importExport"))
        #expect(learningPanelSource.contains("case .languageSpaceManagement"))
        #expect(learningPanelSource.contains("entryLearningContent"))
        // E6: the preview card is fed the real "will-send" projection seam.
        #expect(learningPanelSource.contains("RequestPreviewCard("))
        #expect(learningPanelSource.contains("projection: aiRequestPreviewActions.projection(entry)"))
    }

    @Test("Pad learning panel keeps content away from trailing edge")
    func padLearningPanelKeepsContentAwayFromTrailingEdge() throws {
        let mainSource = try String(contentsOf: sourceFileURL(named: "PadMainView.swift"), encoding: .utf8)
        let learningPanelSource = try String(
            contentsOf: sourceFileURL(named: "PadLearningPanelView.swift"),
            encoding: .utf8
        )

        #expect(mainSource.contains("private let learningPanelTrailingInset: CGFloat = 24"))
        #expect(mainSource.contains(".padding(.trailing, learningPanelTrailingInset)"))
        #expect(learningPanelSource.contains("private let contentPadding"))
        #expect(learningPanelSource.contains("trailing: 32"))
        #expect(learningPanelSource.contains("EdgeInsets("))
    }

    @Test("Mac footer actions route to visible workspace content")
    func macFooterActionsRouteToVisibleWorkspaceContent() {
        #expect(MacFooterAction.languageSpace.section == .settings)
        #expect(MacFooterAction.languageSpace.route == .languageSpaceManagement)
        #expect(MacFooterAction.aiProvider.section == .settings)
        #expect(MacFooterAction.aiProvider.route == .settings(SettingsCapability.Kind.aiProvider))
        #expect(MacFooterAction.sync.section == .settings)
        #expect(MacFooterAction.sync.route == .settings(SettingsCapability.Kind.sync))
        #expect(MacFooterAction.settings.section == .settings)
        #expect(MacFooterAction.settings.route == .overview)
    }

    @Test("Settings capability chrome uses UI localization keys")
    func settingsCapabilityChromeUsesUILocalizationKeys() {
        #expect(SettingsCapability.Kind.languageSpace.localizedTitleKey == "settings.languageSpace.title")
        #expect(SettingsCapability.Kind.interfaceLanguage.localizedTitleKey == "settings.interfaceLanguage.title")
        #expect(SettingsCapability.Kind.aiProvider.localizedTitleKey == "settings.aiProvider.title")
        #expect(SettingsCapability.Kind.importExport.localizedTitleKey == "settings.importExport.title")
        #expect(SettingsCapability.Kind.allCases.contains(.importExport))
        #expect(!SettingsCapability.Kind.allCases.map(\.rawValue).contains("export"))
        #expect(CapabilityStatus.ready.localizedTitleKey == "capabilityStatus.ready")
        #expect(CapabilityStatus.mockOnly.localizedTitleKey == "capabilityStatus.mockOnly")
        #expect(CapabilityStatus.unavailable.localizedTitleKey == "capabilityStatus.unavailable")
    }

    @Test("iPhone settings list omits duplicate current-space explainer")
    func phoneSettingsListOmitsDuplicateCurrentSpaceExplainer() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PhoneMainSections.swift"), encoding: .utf8)

        #expect(source.contains("struct SettingsView: View"))
        #expect(source.contains("PhonePage("))
        #expect(source.contains("showsContextHeader: false"))
        #expect(source.contains("ForEach(capabilities)"))
        #expect(!source.contains("\"phone.settings.currentSpace.title\""))
        #expect(!source.contains("\"phone.settings.currentSpace.subtitle\""))
    }

    @Test("Onboarding bottom action stays constrained on wide Mac and iPad windows")
    func onboardingBottomActionStaysConstrainedOnWideMacAndIPadWindows() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(source.contains("private let onboardingContentMaxWidth: CGFloat = 680"))
        #expect(source.contains("private let onboardingBottomActionMaxWidth: CGFloat = 520"))
        #expect(source.contains("createButtonContent(maxWidth: onboardingBottomActionMaxWidth)"))
        #expect(source.contains(".frame(maxWidth: maxWidth)"))
        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .center)"))
    }

    @Test("Onboarding uses inline wide layout on iPad instead of pinned bottom action")
    func onboardingUsesInlineWideLayoutOnIPadInsteadOfPinnedBottomAction() throws {
        let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

        #expect(source.contains("usesInlineWideOnboardingLayout(in: size)"))
        #expect(source.contains("inlineCreateButton"))
        #expect(source.contains("onboardingWideTopPadding(in: size)"))
        #expect(source.contains("compactOnboardingContentWithBottomAction"))
    }

    @Test("Interface language option keys are stable")
    func interfaceLanguageOptionKeysAreStable() {
        #expect(interfaceLanguagePreferenceTitleKey(for: .system) == "settings.interfaceLanguage.system")
        #expect(interfaceLanguagePreferenceTitleKey(for: .english) == "settings.interfaceLanguage.english")
        #expect(interfaceLanguagePreferenceTitleKey(for: .simplifiedChinese) == "settings.interfaceLanguage.zhHans")
        #expect(interfaceLanguagePreferenceTitleKey(for: .spanish) == "settings.interfaceLanguage.spanish")
        #expect(interfaceLanguagePreferenceTitleKey(for: .japanese) == "settings.interfaceLanguage.japanese")
        #expect(interfaceLanguagePreferenceTitleKey(for: .french) == "settings.interfaceLanguage.french")
        #expect(interfaceLanguagePreferenceTitleKey(for: .german) == "settings.interfaceLanguage.german")
        #expect(interfaceLanguagePreferenceTitleKey(for: .korean) == "settings.interfaceLanguage.korean")
        #expect(interfaceLanguagePreferenceTitleKey(for: .russian) == "settings.interfaceLanguage.russian")
    }

    @Test("Interface language list exposes system plus first batch options")
    func interfaceLanguageListExposesFirstBatchOptions() {
        #expect(InterfaceLanguagePreference.allCases.map(interfaceLanguagePreferenceTitleKey(for:)) == [
            "settings.interfaceLanguage.system",
            "settings.interfaceLanguage.english",
            "settings.interfaceLanguage.zhHans",
            "settings.interfaceLanguage.spanish",
            "settings.interfaceLanguage.japanese",
            "settings.interfaceLanguage.french",
            "settings.interfaceLanguage.german",
            "settings.interfaceLanguage.korean",
            "settings.interfaceLanguage.russian",
        ])
    }

    @Test("Interface language option resources use native language names")
    func interfaceLanguageOptionResourcesUseNativeLanguageNames() throws {
        let catalogURL = try #require(localizableCatalogURL())
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let expectedNativeNames = [
            "settings.interfaceLanguage.english": "English",
            "settings.interfaceLanguage.zhHans": "简体中文",
            "settings.interfaceLanguage.spanish": "Español",
            "settings.interfaceLanguage.japanese": "日本語",
            "settings.interfaceLanguage.french": "Français",
            "settings.interfaceLanguage.german": "Deutsch",
            "settings.interfaceLanguage.korean": "한국어",
            "settings.interfaceLanguage.russian": "Русский",
        ]
        let interfaceLocales = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]

        for (key, expectedName) in expectedNativeNames {
            let entry = try #require(strings[key] as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])

            for locale in interfaceLocales {
                let localization = try #require(localizations[locale] as? [String: Any])
                let stringUnit = try #require(localization["stringUnit"] as? [String: Any])

                #expect(stringUnit["value"] as? String == expectedName)
            }
        }
    }

    @Test("Explicit interface language drives localized chrome lookup")
    func explicitInterfaceLanguageDrivesLocalizedChromeLookup() {
        withLocalizedChromeLanguageCode("en") {
            #expect(localizedString("tab.settings") == "Settings")
        }

        withLocalizedChromeLanguageCode("zh-Hans") {
            #expect(localizedString("tab.settings") == "设置")
        }

        withLocalizedChromeLanguageCode("es") {
            #expect(localizedString("tab.settings") == "Ajustes")
        }
    }

    @Test("System interface language resolves through supported bundle languages")
    func systemInterfaceLanguageResolvesThroughSupportedBundleLanguages() {
        #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(
            systemLanguageCodes: ["pt-BR", "es-MX", "en"]
        ) == "es")
        #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(
            systemLanguageCodes: ["zh-Hans-CN", "en"]
        ) == "zh-Hans")
        #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(
            systemLanguageCodes: ["pt-BR"]
        ) == "en")
    }

    @Test("Learning language display projection stays in UI layer")
    func learningLanguageDisplayProjectionStaysInUILayer() throws {
        let coreSource = try String(contentsOf: coreSourceFileURL(named: "LearningLanguage.swift"), encoding: .utf8)
        let uiSource = try String(contentsOf: sourceFileURL(named: "InterfaceLocalization.swift"), encoding: .utf8)

        #expect(!coreSource.contains("ChineseUI"))
        #expect(uiSource.contains("LearningLanguageDisplayPolicy"))
    }

    @Test("Settings capability detail chrome uses UI localization keys")
    func settingsCapabilityDetailChromeUsesUILocalizationKeys() {
        for kind in SettingsCapability.Kind.allCases {
            let keys = settingsCapabilityDetailLocalizationKeys(for: kind)

            #expect(keys.summary == "settings.\(kind.rawValue).summary")
            #expect(keys.detail == "settings.\(kind.rawValue).detail")
            #expect(keys.nextRequirement == "settings.\(kind.rawValue).nextRequirement")
        }

        #expect(settingsCurrentBoundaryTitleKey == "settings.detail.currentBoundary")
        #expect(settingsNextRequirementTitleKey == "settings.detail.nextRequirement")
        #expect(settingsNoSideEffectsTitleKey == "settings.detail.noSideEffects")
        #expect(settingsNoSideEffectsBodyKey == "settings.detail.noSideEffects.body")
    }

    @Test("Import export setting resources are present and export-only keys are removed")
    func importExportSettingResourcesArePresentAndExportOnlyKeysAreRemoved() throws {
        let catalogURL = try #require(localizableCatalogURL())
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])

        for suffix in ["title", "summary", "detail", "nextRequirement"] {
            #expect(strings["settings.importExport.\(suffix)"] != nil)
            #expect(strings["settings.export.\(suffix)"] == nil)
        }
    }

    private func localizableCatalogURL() -> URL? {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LangoTraceUI/Resources/Localizable.xcstrings")
    }

    private func coreSourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LangoTraceCore")
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceCore")
            .appendingPathComponent(fileName)
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
