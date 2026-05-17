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
        nativeLanguage: "中文",
        targetLanguage: "英语",
        level: .b1
    )

    let space = draft.makeLanguageSpacePreview()

    #expect(space.name == "英语空间")
    #expect(space.nativeLanguage == "中文")
    #expect(space.targetLanguage == "英语")
    #expect(space.level == .b1)
    #expect(space.displayContext == "中文 -> 英语 · B1")
}
