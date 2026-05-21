import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Interface language settings page")
struct InterfaceLanguageSettingsPageTests {
    @Test("Detail uses choice-first layout without persistent explanation cards")
    func detailUsesChoiceFirstLayoutWithoutPersistentExplanationCards() throws {
        let source = try String(contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"), encoding: .utf8)

        #expect(source.contains("if capability.kind != .interfaceLanguage {"))
        #expect(source.contains("header"))
        #expect(source.contains("interfaceLanguageSettingsContent"))
        #expect(source.contains("interfaceLanguageOptionRow"))
        #expect(source.contains("settings.interfaceLanguage.selectionFootnote"))
        #expect(!source.contains("interfaceLanguagePicker"))
        #expect(!source.contains("localizedText(\"settings.interfaceLanguage.explanation\")"))
        #expect(!source.contains("localizedText(\"settings.interfaceLanguage.systemBoundary\")"))
        #expect(!source.contains("localizedText(\"settings.interfaceLanguage.contentBoundary\")"))
    }

    @Test("Option rows expose selection state and avoid duplicate writes")
    func optionRowsExposeSelectionStateAndAvoidDuplicateWrites() throws {
        let source = try String(contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"), encoding: .utf8)

        #expect(source.contains("guard interfaceLanguagePreference != preference else {"))
        #expect(source.contains("LangoTraceDesign.Density.minimumTouchTarget"))
        #expect(source.contains(
            ".accessibilityValue(localizedText(isSelected ? \"accessibility.selected\" : \"accessibility.unselected\"))"
        ))
        #expect(source.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
        #expect(source.contains(".accessibilityHidden(true)"))
    }

    @Test("Selection footnote stays concise")
    func selectionFootnoteStaysConcise() throws {
        let catalogURL = try #require(localizableCatalogURL())
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let entry = try #require(strings["settings.interfaceLanguage.selectionFootnote"] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: Any])

        let zhHans = try localizedCatalogValue(localizations: localizations, locale: "zh-Hans")
        let english = try localizedCatalogValue(localizations: localizations, locale: "en")

        #expect(zhHans.count <= 32)
        #expect(english.count <= 100)
        #expect(!zhHans.contains("StoreKit"))
        #expect(!english.localizedCaseInsensitiveContains("per-app language"))
    }

    @Test("iPad and Mac workspaces route interface language through shared detail")
    func iPadAndMacWorkspacesRouteInterfaceLanguageThroughSharedDetail() throws {
        let padSource = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let macSource = try String(contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"), encoding: .utf8)

        #expect(padSource.contains("SettingsCapabilityDetailView("))
        #expect(padSource.contains("interfaceLanguagePreference: interfaceLanguagePreference"))
        #expect(padSource.contains("onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange"))

        #expect(macSource.contains("SettingsCapabilityDetailView("))
        #expect(macSource.contains("presentation: .embeddedInExistingScroll"))
        #expect(macSource.contains("interfaceLanguagePreference: interfaceLanguagePreference"))
        #expect(macSource.contains("onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange"))
    }

    @Test("Mac Settings scene keeps interface language available without a language space")
    func macSettingsSceneKeepsInterfaceLanguageAvailableWithoutLanguageSpace() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"), encoding: .utf8)

        #expect(source.contains("selectedCapabilityKind == .interfaceLanguage"))
        #expect(source.contains("settingsDetailLanguageSpace(for: selectedCapability)"))
        #expect(source.contains("interfaceLanguagePlaceholderSpace"))
        #expect(source.contains("SettingsCapabilityDetailView("))
        #expect(!source.contains("else if let languageSpace, let selectedCapability"))
    }

    @Test("Mac inspector keeps interface language explanation short")
    func macInspectorKeepsInterfaceLanguageExplanationShort() throws {
        let source = try String(contentsOf: sourceFileURL(named: "MacInspectorContent.swift"), encoding: .utf8)

        #expect(source.contains("if kind == .interfaceLanguage"))
        #expect(source.contains("textKey: \"settings.interfaceLanguage.selectionFootnote\""))
        #expect(!source.contains("settingsCapabilityDetailLocalizationKeys(for: capability.kind).nextRequirement"))
    }

    private func localizableCatalogURL() -> URL? {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LangoTraceUI/Resources/Localizable.xcstrings")
    }

    private func localizedCatalogValue(localizations: [String: Any], locale: String) throws -> String {
        let localization = try #require(localizations[locale] as? [String: Any])
        let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
        return try #require(stringUnit["value"] as? String)
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
