import Foundation
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Launch recovery presentation")
struct LaunchRecoveryPresentationTests {
    private let requiredLanguages: Set<String> = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]

    @Test("Recovery failure panel is shown only on the welcome phase after a failed recovery")
    func recoveryFailurePanelShownOnlyOnWelcomeAfterFailure() {
        #expect(LangoTraceRootView.showsLaunchRecoveryFailurePanel(phase: .welcome, launchRecoveryFailed: true))
        #expect(!LangoTraceRootView.showsLaunchRecoveryFailurePanel(phase: .welcome, launchRecoveryFailed: false))
        #expect(!LangoTraceRootView.showsLaunchRecoveryFailurePanel(phase: .onboarding, launchRecoveryFailed: true))
        #expect(!LangoTraceRootView.showsLaunchRecoveryFailurePanel(phase: .main, launchRecoveryFailed: true))
    }

    @Test("Launch recovery copy is localized for all interface languages")
    func launchRecoveryCopyIsLocalized() throws {
        let strings = try catalogStrings()

        for key in ["launchRecovery.failed.title", "launchRecovery.failed.message", "launchRecovery.retry"] {
            let entry = try #require(strings[key] as? [String: Any], "missing catalog key \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any])
            #expect(
                Set(localizations.keys) == requiredLanguages,
                "\(key) must be localized for all interface languages"
            )
        }
    }

    @Test("Root view wires the failure panel and retry action into the welcome phase")
    func rootViewWiresFailurePanelIntoWelcomePhase() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LangoTraceRootView.swift"), encoding: .utf8)

        #expect(source.contains("launchRecoveryFailed: Bool = false"))
        #expect(source.contains("LaunchRecoveryFailurePanel(onRetry: onRetryLaunchRecovery)"))
        #expect(source.contains("localizedText(\"launchRecovery.failed.title\")"))
        #expect(source.contains("localizedText(\"launchRecovery.failed.message\")"))
        #expect(source.contains("localizedText(\"launchRecovery.retry\")"))
    }

    @Test("Root view init performs no chrome language side effect")
    func rootViewInitPerformsNoChromeLanguageSideEffect() throws {
        // UIS-16 / UIV-24: the resolver is applied once from the App initializer
        // (LangoTraceInterfaceChrome) and updated via onAppear/onChange; view init
        // must stay free of global mutations.
        let source = try String(contentsOf: sourceFileURL(named: "LangoTraceRootView.swift"), encoding: .utf8)

        #expect(!source.contains("LocalizedChromeLanguageResolver.use"))
        #expect(source.contains(".onAppear(perform: applyInterfaceChromeLanguage)"))
        #expect(source.contains(".onChange(of: interfaceLanguagePreference)"))
        #expect(source.contains("LangoTraceInterfaceChrome.applyLanguage(interfaceLanguagePreference)"))
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
