import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Phone root context chrome")
struct PhoneRootContextChromeTests {
    private func makeSpace() -> LanguageSpacePreview {
        LanguageSpacePreview(
            id: "en",
            name: "English",
            nativeLanguage: "中文",
            targetLanguage: "英语",
            targetLanguageCode: "en",
            level: .b1
        )
    }

    @Test("Chrome reflects the language space display context")
    func chromeReflectsLanguageSpaceDisplayContext() {
        let space = makeSpace()
        let chrome = PhoneRootContextChrome.make(languageSpace: space, hasSettings: true)

        #expect(chrome.displayContext == space.displayContext)
    }

    @Test("Chrome compact context is the target language alone (round 4: level dropped from the chip)")
    func chromeCompactContextIsTargetLanguageOnly() {
        let space = makeSpace()
        let chrome = PhoneRootContextChrome.make(languageSpace: space, hasSettings: true)

        // The nav-bar chip shows only the target language — one space maps to one
        // language (core decision #4), so the language alone identifies the space.
        // The level (B1) is a rarely-changing self-assessment and is intentionally
        // omitted here; spec/002 §54 / §157 phrase the example as "例如 英语 · B1".
        #expect(chrome.compactContext == space.targetLanguage)
        #expect(chrome.compactContext == "英语")
        #expect(!chrome.compactContext.contains(space.level.rawValue))
        // The full native -> target · level context is still available for VoiceOver.
        #expect(chrome.displayContext == space.displayContext)
    }

    @Test("Chrome shows language switcher and settings when a settings action is provided")
    func chromeShowsLanguageSwitcherAndSettingsWhenSettingsProvided() {
        let chrome = PhoneRootContextChrome.make(languageSpace: makeSpace(), hasSettings: true)

        #expect(chrome.showsLanguageSwitcher)
        #expect(chrome.showsSettings)
    }

    @Test("Chrome hides settings when no settings action is available")
    func chromeHidesSettingsWhenNoSettingsAction() {
        let chrome = PhoneRootContextChrome.make(languageSpace: makeSpace(), hasSettings: false)

        #expect(chrome.showsLanguageSwitcher)
        #expect(!chrome.showsSettings)
    }

    @Test("Every phone root tab declares the shared context toolbar")
    func allPhoneRootTabsProvideContextToolbar() {
        for tab in PhoneRootTab.allCases {
            #expect(tab.providesRootContextToolbar)
        }
        // Structural regression guard for the original "reading tab missing gear" bug.
        #expect(PhoneRootTab.reading.providesRootContextToolbar)
    }

    @Test("Context chrome accessibility keys resolve in the localization catalog")
    func chromeAccessibilityKeysResolve() {
        for key in [
            "tab.settings",
            "languageSpace.switcher.label",
            "languageSpace.switcher.hint",
        ] {
            #expect(localizedString(key) != key)
        }
    }

    @Test("Phone root context toolbar lives in its own source file")
    func phoneRootContextToolbarSourceCarriesSharedChrome() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "PhoneRootContextToolbar.swift"),
            encoding: .utf8
        )

        #expect(source.contains("func phoneRootContextToolbar("))
        #expect(source.contains(".navigationBarTitleDisplayMode(.inline)"))
        #expect(source.contains(".topBarLeading"))
        #expect(source.contains(".topBarTrailing"))
        #expect(source.contains("Button(action: onSettingsAction)"))
        #expect(source.contains("Button(action: onLanguageSpaceAction)"))
        #expect(source.contains(#"accessibilityLabel(localizedText("tab.settings"))"#))
    }

    @Test("PhonePage gates the context toolbar on showsContextHeader so settings stays suppressed")
    func phonePageGatesContextToolbarOnShowsContextHeader() throws {
        let sections = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSections.swift"),
            encoding: .utf8
        )

        // The shared toolbar is applied via the gated branch, never unconditionally,
        // so SettingsView (showsContextHeader: false) keeps its plain title.
        #expect(sections.contains("phoneRootContextToolbar("))
        #expect(sections.contains("if showsContextHeader"))
        #expect(sections.contains("showsContextHeader: false"))
        // The retired in-body header must not come back.
        #expect(!sections.contains("PhoneContextHeader("))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
