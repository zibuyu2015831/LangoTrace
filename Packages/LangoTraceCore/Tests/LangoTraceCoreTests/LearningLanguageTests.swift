@testable import LangoTraceCore
import Testing

@Test("Learning language exposes separate display names for Chinese UI and prompts")
func learningLanguageExposesSeparateDisplayNames() {
    let english = LearningLanguage.english
    let japanese = LearningLanguage.japanese
    let chinese = LearningLanguage.zhHans

    #expect(english.code == "en")
    #expect(english.nativeName == "English")
    #expect(english.zhHansName == "英语")
    #expect(english.englishName == "English")
    #expect(english.pickerMenuTitleForChineseUI == "English（英语）")
    #expect(english.selectedTitleForChineseUI == "English")
    #expect(english.spaceNameForChineseUI == "英语空间")
    #expect(english.promptLanguageName == "English")

    #expect(japanese.pickerMenuTitleForChineseUI == "日本語（日语）")
    #expect(japanese.selectedTitleForChineseUI == "日本語")
    #expect(japanese.promptLanguageName == "Japanese")

    #expect(chinese.pickerMenuTitleForChineseUI == "中文")
    #expect(chinese.selectedTitleForChineseUI == "中文")
    #expect(chinese.promptLanguageName == "Chinese")
}

@Test("Learning language lookup uses stable codes")
func learningLanguageLookupUsesStableCodes() {
    #expect(LearningLanguage.find(code: "zh-Hans") == .zhHans)
    #expect(LearningLanguage.find(code: "en") == .english)
    #expect(LearningLanguage.find(code: "missing") == nil)
}

@Test("Target language options exclude the selected native language")
func targetLanguageOptionsExcludeSelectedNativeLanguage() {
    let chineseNativeTargets = LearningLanguage.targetLanguages(excludingNativeCode: "zh-Hans")
    let englishNativeTargets = LearningLanguage.targetLanguages(excludingNativeCode: "en")

    #expect(!chineseNativeTargets.map(\.code).contains("zh-Hans"))
    #expect(chineseNativeTargets.first == .english)
    #expect(!englishNativeTargets.map(\.code).contains("en"))
    #expect(englishNativeTargets.first == .japanese)
}
