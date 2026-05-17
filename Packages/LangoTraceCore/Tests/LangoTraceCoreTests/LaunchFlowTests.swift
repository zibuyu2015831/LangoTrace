@testable import LangoTraceCore
import Testing

@Test("Launch route enters onboarding when there is no language space")
func launchRouteEntersOnboardingWithoutLanguageSpace() {
    #expect(LaunchRoute.route(hasLanguageSpace: false) == .onboarding)
}

@Test("Launch route enters main when a language space exists")
func launchRouteEntersMainWithLanguageSpace() {
    #expect(LaunchRoute.route(hasLanguageSpace: true) == .main)
}

@Test("Onboarding draft creates an English language space preview")
func onboardingDraftCreatesLanguageSpacePreview() {
    let draft = OnboardingDraft(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1
    )

    let space = draft.makeLanguageSpacePreview()

    #expect(space.id == "en")
    #expect(space.name == "英语空间")
    #expect(space.nativeLanguage == "中文")
    #expect(space.targetLanguage == "英语")
    #expect(space.level == .b1)
    #expect(space.displayContext == "中文 -> 英语 · B1")
}

@Test("Onboarding draft defaults to Chinese native and English target")
func onboardingDraftDefaultsToChineseNativeAndEnglishTarget() {
    let draft = OnboardingDraft()

    #expect(draft.nativeLanguageCode == "zh-Hans")
    #expect(draft.targetLanguageCode == "en")
    #expect(draft.level == .b1)
    #expect(draft.resolvedNativeLanguage == .zhHans)
    #expect(draft.resolvedTargetLanguage == .english)
}

@Test("Onboarding draft normalizes invalid or same-language selections")
func onboardingDraftNormalizesInvalidOrSameLanguageSelections() {
    let sameLanguageDraft = OnboardingDraft(
        nativeLanguageCode: "en",
        targetLanguageCode: "en",
        level: .a2
    ).normalized()

    #expect(sameLanguageDraft.nativeLanguageCode == "en")
    #expect(sameLanguageDraft.targetLanguageCode == "ja")
    #expect(sameLanguageDraft.level == .a2)

    let invalidDraft = OnboardingDraft(
        nativeLanguageCode: "missing-native",
        targetLanguageCode: "missing-target",
        level: .c1
    ).normalized()

    #expect(invalidDraft.nativeLanguageCode == "zh-Hans")
    #expect(invalidDraft.targetLanguageCode == "en")
    #expect(invalidDraft.level == .c1)
}
