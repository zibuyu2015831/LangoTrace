import LangoTraceAI
import LangoTraceCore
import Testing

@Test("Language support validator accepts English JSON sample with target word count")
func languageSupportValidatorAcceptsEnglishSampleWithTargetWordCount() {
    let validator = AIProviderLanguageSupportValidator()
    let sample = "Today I opened the kitchen window before breakfast and wrote a note about the rain, " +
        "the quiet street, and the warm cup of tea beside my notebook."
    let response = """
    {"sample":"\(sample)"}
    """

    let result = validator.validateResponseText(
        response,
        languageContext: AIProviderProbeLanguageContext(languageCode: "en")
    )

    #expect(result.isValid)
    #expect(result.sample != nil)
}

@Test("Language support validator accepts fenced JSON with a valid sample")
func languageSupportValidatorAcceptsFencedJSONWithValidSample() {
    let validator = AIProviderLanguageSupportValidator()
    let sample = "Today I opened the kitchen window before breakfast and wrote a note about the rain, " +
        "the quiet street, and the warm cup of tea beside my notebook."
    let response = """
    ```json
    {"sample":"\(sample)","note":"synthetic configuration sample"}
    ```
    """

    let result = validator.validateResponseText(
        response,
        languageContext: AIProviderProbeLanguageContext(languageCode: "en")
    )

    #expect(result.isValid)
    #expect(result.sample == sample)
}

@Test("Language support validator rejects English short sentence")
func languageSupportValidatorRejectsEnglishShortSentence() {
    let validator = AIProviderLanguageSupportValidator()
    let response = #"{"sample":"I wrote a note today."}"#

    let result = validator.validateResponseText(
        response,
        languageContext: AIProviderProbeLanguageContext(languageCode: "en")
    )

    #expect(!result.isValid)
    #expect(result.errorCategory == .invalidResponse)
    #expect(result.failureReason == .sampleTooShort)
}

@Test("Language support validator rejects Japanese sample without kana")
func languageSupportValidatorRejectsJapaneseWithoutKana() {
    let validator = AIProviderLanguageSupportValidator()
    let response = #"{"sample":"今日早晨我在厨房窗边记录普通生活片刻随后准备整理这些内容用于语言学习练习和复习"}"#

    let result = validator.validateResponseText(
        response,
        languageContext: AIProviderProbeLanguageContext(languageCode: "ja")
    )

    #expect(!result.isValid)
    #expect(result.errorCategory == .invalidResponse)
    #expect(result.failureReason == .scriptMismatch)
}

@Test("Language support validator rejects Korean sample without Hangul")
func languageSupportValidatorRejectsKoreanWithoutHangul() {
    let validator = AIProviderLanguageSupportValidator()
    let response = """
    {"sample":"Today I opened the kitchen window and recorded an ordinary morning moment for language practice."}
    """

    let result = validator.validateResponseText(
        response,
        languageContext: AIProviderProbeLanguageContext(languageCode: "ko")
    )

    #expect(!result.isValid)
    #expect(result.errorCategory == .invalidResponse)
    #expect(result.failureReason == .scriptMismatch)
}

@Test("Language support validator rejects Chinese sample written in English")
func languageSupportValidatorRejectsChineseWrittenInEnglish() {
    let validator = AIProviderLanguageSupportValidator()
    let sample = "Today I opened the kitchen window before breakfast and wrote a short note about the rain, " +
        "the quiet street, and the warm cup of tea beside my notebook."
    let response = """
    {"sample":"\(sample)"}
    """

    let result = validator.validateResponseText(
        response,
        languageContext: AIProviderProbeLanguageContext(languageCode: "zh-Hans")
    )

    #expect(!result.isValid)
    #expect(result.errorCategory == .invalidResponse)
    #expect(result.failureReason == .scriptMismatch)
}

@Test("Language support validator rejects unsupported language code before network use")
func languageSupportValidatorRejectsUnsupportedLanguageCode() {
    let validator = AIProviderLanguageSupportValidator()
    let response = #"{"sample":"A valid looking sample is irrelevant for unsupported languages."}"#

    let result = validator.validateResponseText(
        response,
        languageContext: AIProviderProbeLanguageContext(languageCode: "it")
    )

    #expect(!result.isValid)
    #expect(result.errorCategory == .invalidResponse)
    #expect(result.failureReason == .unsupportedLanguageCode)
}

@Test("Language support validator reports missing sample JSON without preserving response text")
func languageSupportValidatorReportsMissingSampleJSON() {
    let validator = AIProviderLanguageSupportValidator()

    let result = validator.validateResponseText(
        "The language works, but this is not JSON.",
        languageContext: AIProviderProbeLanguageContext(languageCode: "en")
    )

    #expect(!result.isValid)
    #expect(result.errorCategory == .invalidResponse)
    #expect(result.failureReason == .missingSampleJSON)
    #expect(result.sample == nil)
}
