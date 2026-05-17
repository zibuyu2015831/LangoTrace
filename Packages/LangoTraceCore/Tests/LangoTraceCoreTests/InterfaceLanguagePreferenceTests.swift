@testable import LangoTraceCore
import Testing

@Test("Interface language preference follows system and falls back to English")
func interfaceLanguagePreferenceFollowsSystemAndFallsBackToEnglish() {
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["zh-Hans-CN"]) == "zh-Hans")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["ja-JP"]) == "en")
    #expect(InterfaceLanguagePreference.english.resolvedLanguageCode(systemLanguageCodes: ["zh-Hans-CN"]) == "en")
    #expect(
        InterfaceLanguagePreference.simplifiedChinese.resolvedLanguageCode(systemLanguageCodes: ["en-US"]) == "zh-Hans"
    )
}

@Test("Interface language preference uses stable storage values")
func interfaceLanguagePreferenceUsesStableStorageValues() {
    #expect(InterfaceLanguagePreference.system.storageValue == "system")
    #expect(InterfaceLanguagePreference.english.storageValue == "en")
    #expect(InterfaceLanguagePreference.simplifiedChinese.storageValue == "zh-Hans")
    #expect(InterfaceLanguagePreference(storageValue: "en") == .english)
    #expect(InterfaceLanguagePreference(storageValue: "zh-Hans") == .simplifiedChinese)
    #expect(InterfaceLanguagePreference(storageValue: "missing") == .system)
}

@Test("Interface language preference does not mutate language space context")
func interfaceLanguagePreferenceDoesNotMutateLanguageSpaceContext() {
    let languageSpace = LanguageSpacePreview(
        id: "en",
        name: "英语空间",
        nativeLanguage: "中文",
        targetLanguage: "English",
        level: .b1
    )

    let result = InterfaceLanguagePreference.english.applying(to: languageSpace)

    #expect(result == languageSpace)
    #expect(result.nativeLanguage == "中文")
    #expect(result.targetLanguage == "English")
}
