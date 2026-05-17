@testable import LangoTraceCore
import Testing

@Test("Interface language preference follows system and falls back to English")
func interfaceLanguagePreferenceFollowsSystemAndFallsBackToEnglish() {
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["zh-Hans-CN"]) == "zh-Hans")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["es-MX"]) == "es")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["ja-JP"]) == "ja")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["fr-CA"]) == "fr")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["de-AT"]) == "de")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["ko-KR"]) == "ko")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["ru-RU"]) == "ru")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["zh-Hant-TW"]) == "en")
    #expect(InterfaceLanguagePreference.system.resolvedLanguageCode(systemLanguageCodes: ["it-IT"]) == "en")
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
    #expect(InterfaceLanguagePreference.spanish.storageValue == "es")
    #expect(InterfaceLanguagePreference.japanese.storageValue == "ja")
    #expect(InterfaceLanguagePreference.french.storageValue == "fr")
    #expect(InterfaceLanguagePreference.german.storageValue == "de")
    #expect(InterfaceLanguagePreference.korean.storageValue == "ko")
    #expect(InterfaceLanguagePreference.russian.storageValue == "ru")
    #expect(InterfaceLanguagePreference(storageValue: "en") == .english)
    #expect(InterfaceLanguagePreference(storageValue: "zh-Hans") == .simplifiedChinese)
    #expect(InterfaceLanguagePreference(storageValue: "es") == .spanish)
    #expect(InterfaceLanguagePreference(storageValue: "ja") == .japanese)
    #expect(InterfaceLanguagePreference(storageValue: "fr") == .french)
    #expect(InterfaceLanguagePreference(storageValue: "de") == .german)
    #expect(InterfaceLanguagePreference(storageValue: "ko") == .korean)
    #expect(InterfaceLanguagePreference(storageValue: "ru") == .russian)
    #expect(InterfaceLanguagePreference(storageValue: "missing") == .system)
}

@Test("Interface language preference exposes system plus first batch interface languages")
func interfaceLanguagePreferenceExposesFirstBatchInterfaceLanguages() {
    #expect(InterfaceLanguagePreference.allCases.map(\.storageValue) == [
        "system",
        "en",
        "zh-Hans",
        "es",
        "ja",
        "fr",
        "de",
        "ko",
        "ru",
    ])

    #expect(InterfaceLanguagePreference.supportedLanguageCodes == [
        "en",
        "zh-Hans",
        "es",
        "ja",
        "fr",
        "de",
        "ko",
        "ru",
    ])
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
