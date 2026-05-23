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
        #expect(source.contains(".accessibilityValue(localizedText(isSelected ?"))
        #expect(source.contains("\"accessibility.selected\""))
        #expect(source.contains("\"accessibility.unselected\""))
        #expect(source.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
        #expect(source.contains("LangoTraceDesign.Density.minimumTouchTarget"))
    }

    @Test("Shared detail accepts global settings without placeholder language space")
    func sharedDetailAcceptsGlobalSettingsWithoutPlaceholderLanguageSpace() throws {
        let detailSource = try String(
            contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"),
            encoding: .utf8
        )
        let sceneSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"),
            encoding: .utf8
        )

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
        let sceneSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"),
            encoding: .utf8
        )

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

    @Test("Phone hero primary action uses a quieter dark-mode CTA token")
    func phoneHeroPrimaryActionUsesQuieterDarkModeCTAToken() throws {
        let designSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceDesign.swift"),
            encoding: .utf8
        )
        let phoneSource = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )

        #expect(designSource.contains("static var primaryActionFill: Color"))
        #expect(designSource.contains("static var primaryActionForeground: Color"))
        #expect(designSource.contains("dark: 0x23786A"))
        #expect(phoneSource.contains(".tint(LangoTraceDesign.ColorToken.primaryActionFill)"))
        #expect(
            phoneSource.contains(
                ".foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)"
            )
        )
    }

    @Test("Large filled primary actions use dedicated CTA tokens")
    func largeFilledPrimaryActionsUseDedicatedCTATokens() throws {
        let sourcesRequiringPrimaryActionTint = [
            "WelcomeView+Layout.swift",
            "OnboardingView.swift",
            "AIProviderSettingsView.swift",
            "AIProviderSettingsComponents.swift",
            "SyncS3DraftView.swift",
            "SyncSettingsView.swift",
            "PracticeControlBar.swift",
            "PadWorkspaceBar.swift",
            "MacEntryEditorSheet.swift",
        ]

        for fileName in sourcesRequiringPrimaryActionTint {
            let source = try String(contentsOf: sourceFileURL(named: fileName), encoding: .utf8)
            #expect(
                source.contains("LangoTraceDesign.ColorToken.primaryActionFill"),
                "\(fileName) must use the dedicated filled primary action token."
            )
        }

        let welcomeSource = try collapsedSource(named: "WelcomeView+Layout.swift")
        let onboardingSource = try collapsedSource(named: "OnboardingView.swift")
        let syncS3Source = try collapsedSource(named: "SyncS3DraftView.swift")
        let syncSettingsSource = try collapsedSource(named: "SyncSettingsView.swift")
        let macEditorSource = try collapsedSource(named: "MacEntryEditorSheet.swift")

        #expect(!welcomeSource.contains(prominentButtonUsingTint("deepTeal")))
        #expect(!onboardingSource.contains(prominentButtonUsingTint("deepTeal")))
        #expect(!syncS3Source.contains(prominentButtonUsingTint("accent")))
        #expect(!syncSettingsSource.contains(prominentButtonUsingTint("accent")))
        #expect(!macEditorSource.contains(prominentButtonUsingTint("accent")))
    }

    @Test("Switch controls use a dedicated active fill token")
    func switchControlsUseDedicatedActiveFillToken() throws {
        let designSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceDesign.swift"),
            encoding: .utf8
        )
        #expect(designSource.contains("static var switchOnFill: Color"))
        #expect(designSource.contains("dark: 0x2C8A7B"))

        for fileName in [
            "AIProviderSettingsComponents.swift",
            "SyncSettingsView.swift",
            "SyncS3DraftView.swift",
        ] {
            let source = try String(contentsOf: sourceFileURL(named: fileName), encoding: .utf8)
            #expect(
                source.contains(".tint(LangoTraceDesign.ColorToken.switchOnFill)"),
                "\(fileName) must avoid bright accent switch fills."
            )
        }

        let aiProviderSource = try collapsedSource(named: "AIProviderSettingsComponents.swift")
        let syncSettingsSource = try collapsedSource(named: "SyncSettingsView.swift")

        #expect(!aiProviderSource.contains(switchUsingTint("accent")))
        #expect(!syncSettingsSource.contains(switchUsingTint("accent")))
    }

    @Test("iPad and macOS workbenches use platform surface tokens")
    func padAndMacWorkbenchesUsePlatformSurfaceTokens() throws {
        let padSidebarSource = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let padInspectorSource = try String(
            contentsOf: sourceFileURL(named: "PadLearningPanelView.swift"),
            encoding: .utf8
        )
        let macSource = try String(contentsOf: sourceFileURL(named: "MacMainView.swift"), encoding: .utf8)
        let settingsSceneSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"),
            encoding: .utf8
        )

        #expect(padSidebarSource.contains("LangoTraceDesign.ColorToken.surfaceSidebar.opacity(0.72)"))
        #expect(padInspectorSource.contains("LangoTraceDesign.ColorToken.surfaceInspector.opacity(0.58)"))
        #expect(settingsSceneSource.contains("LangoTraceDesign.ColorToken.surfaceSidebar.opacity(0.72)"))
        #expect(macSource.contains("LangoTraceDesign.ColorToken.surfaceSidebar.opacity(0.72)"))
        #expect(macSource.contains("LangoTraceDesign.ColorToken.surfaceInspector.opacity(0.58)"))
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

    private func collapsedSource(named fileName: String) throws -> String {
        let source = try String(contentsOf: sourceFileURL(named: fileName), encoding: .utf8)
        return source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func prominentButtonUsingTint(_ tokenName: String) -> String {
        ".buttonStyle(.borderedProminent) .tint(LangoTraceDesign.ColorToken.\(tokenName))"
    }

    private func switchUsingTint(_ tokenName: String) -> String {
        ".toggleStyle(.switch) .tint(LangoTraceDesign.ColorToken.\(tokenName))"
    }
}
