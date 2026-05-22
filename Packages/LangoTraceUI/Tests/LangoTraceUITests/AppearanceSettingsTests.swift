import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Appearance settings")
struct AppearanceSettingsTests {
    @Test("Appearance option keys are stable")
    func appearanceOptionKeysAreStable() {
        #expect(appearancePreferenceTitleKey(for: .system) == "settings.appearance.system")
        #expect(appearancePreferenceTitleKey(for: .light) == "settings.appearance.light")
        #expect(appearancePreferenceTitleKey(for: .dark) == "settings.appearance.dark")
        #expect(AppearancePreference.allCases.map(appearancePreferenceTitleKey(for:)) == [
            "settings.appearance.system",
            "settings.appearance.light",
            "settings.appearance.dark",
        ])
    }

    @Test("Detail uses global appearance choices with accessible selected state")
    func detailUsesGlobalAppearanceChoicesWithAccessibleSelectedState() throws {
        let source = try String(contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"), encoding: .utf8)

        #expect(source.contains("appearanceSettingsContent"))
        #expect(source.contains("appearanceOptionRow"))
        #expect(source.contains("guard appearancePreference != preference else {"))
        #expect(source.contains("AppearancePreference.allCases"))
        #expect(source.contains(".accessibilityValue(localizedText(isSelected ? \"accessibility.selected\" : \"accessibility.unselected\"))"))
        #expect(source.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
        #expect(source.contains("LangoTraceDesign.Density.minimumTouchTarget"))
    }

    @Test("Shared detail accepts global settings without placeholder language space")
    func sharedDetailAcceptsGlobalSettingsWithoutPlaceholderLanguageSpace() throws {
        let detailSource = try String(contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"), encoding: .utf8)
        let sceneSource = try String(contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"), encoding: .utf8)

        #expect(detailSource.contains("let languageSpace: LanguageSpacePreview?"))
        #expect(detailSource.contains("requiresLanguageSpaceContext"))
        #expect(detailSource.contains("capability.kind == .appearance"))
        #expect(sceneSource.contains("SettingsCapability.Kind.appearance"))
        #expect(!sceneSource.contains("appearancePlaceholderSpace"))
        #expect(!detailSource.contains("appearancePlaceholderSpace"))
    }

    @Test("iPhone iPad Mac and settings scene pass appearance preference through shared detail")
    func platformsPassAppearancePreferenceThroughSharedDetail() throws {
        let phoneSource = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)
        let padSource = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let macSource = try String(contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"), encoding: .utf8)
        let sceneSource = try String(contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"), encoding: .utf8)

        for source in [phoneSource, padSource, macSource, sceneSource] {
            #expect(source.contains("appearancePreference: appearancePreference"))
            #expect(source.contains("onAppearancePreferenceChange: onAppearancePreferenceChange"))
        }
    }

    @Test("App applies preferred color scheme from appearance preference")
    func appAppliesPreferredColorSchemeFromAppearancePreference() throws {
        let source = try String(contentsOf: appSourceFileURL(named: "LangoTraceApp.swift"), encoding: .utf8)

        #expect(source.contains("UserDefaultsAppearancePreferenceStore"))
        #expect(source.contains("@State private var appearancePreference: AppearancePreference"))
        #expect(source.contains(".preferredColorScheme(appearancePreference.preferredColorScheme)"))
        #expect(source.contains("case .system:"))
        #expect(source.contains("nil"))
        #expect(source.contains("case .light:"))
        #expect(source.contains(".light"))
        #expect(source.contains("case .dark:"))
        #expect(source.contains(".dark"))
    }

    @Test("Design tokens expose approved light and dark palette values")
    func designTokensExposeApprovedLightAndDarkPaletteValues() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LangoTraceDesign.swift"), encoding: .utf8)

        #expect(source.contains("struct LangoTracePalette"))
        #expect(source.contains("static let light"))
        #expect(source.contains("static let dark"))
        #expect(source.contains("hex: 0xF6F1E8"))
        #expect(source.contains("hex: 0x101A18"))
        #expect(source.contains("hex: 0x126B5D"))
        #expect(source.contains("hex: 0x72D2BF"))
        #expect(source.contains("static var paper: Color"))
        #expect(!source.contains("Color(red: 0.965, green: 0.949, blue: 0.918)"))
        #expect(!source.contains("Color(red: 0.425, green: 0.467, blue: 0.500)"))
        #expect(!source.contains("Color(red: 0.690, green: 0.505, blue: 0.215)"))
    }

    @Test("Appearance resources are present in English and Simplified Chinese")
    func appearanceResourcesArePresent() throws {
        let catalogURL = try #require(localizableCatalogURL())
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])

        for key in [
            "settings.appearance.title",
            "settings.appearance.summary",
            "settings.appearance.detail",
            "settings.appearance.nextRequirement",
            "settings.appearance.selectionFootnote",
            "settings.appearance.system",
            "settings.appearance.light",
            "settings.appearance.dark",
        ] {
            let entry = try #require(strings[key] as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])
            _ = try localizedCatalogValue(localizations: localizations, locale: "en")
            _ = try localizedCatalogValue(localizations: localizations, locale: "zh-Hans")
        }
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

    private func appSourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LangoTraceApp")
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
