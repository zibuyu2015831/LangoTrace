@testable import LangoTraceData
import Testing

@Test("Settings capabilities expose interface language without changing learning context")
func settingsCapabilitiesExposeInterfaceLanguageWithoutChangingLearningContext() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let capabilities = repository.settingsCapabilities(for: "en")

    let interfaceLanguage = capabilities.filter { $0.kind == .interfaceLanguage }.first

    #expect(interfaceLanguage != nil)
    #expect(interfaceLanguage?.status == .mockOnly)
    #expect(interfaceLanguage?.summary == "settings.interfaceLanguage.summary")
    #expect(interfaceLanguage?.detail == "settings.interfaceLanguage.detail")
    #expect(interfaceLanguage?.nextRequirement == "settings.interfaceLanguage.nextRequirement")
}

@Test("Settings capabilities expose global appearance without changing learning context")
func settingsCapabilitiesExposeGlobalAppearanceWithoutChangingLearningContext() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let capabilities = repository.settingsCapabilities(for: "en")

    let appearance = capabilities.filter { $0.kind == .appearance }.first

    #expect(appearance != nil)
    #expect(appearance?.status == .ready)
    #expect(appearance?.summary == "settings.appearance.summary")
    #expect(appearance?.detail == "settings.appearance.detail")
    #expect(appearance?.nextRequirement == "settings.appearance.nextRequirement")
    #expect(appearance?.isReadOnly == true)
    #expect(SettingsCapability.Kind.appearance.systemImage == "circle.lefthalf.filled")
}

@Test("Companion leads the settings capabilities as a ready card with a chat icon")
func settingsCapabilitiesLeadWithCompanionCard() {
    #expect(SettingsCapability.Kind.allCases.contains(.companion))
    #expect(SettingsCapability.Kind.companion.systemImage == "bubble.left.and.bubble.right")

    // The settings list surfaces companion as the first capability card, directly under
    // the learner-profile row — preserving its top placement now that it is no longer a
    // bare toggle.
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let first = repository.settingsCapabilities(for: "en").first
    #expect(first?.kind == .companion)
    #expect(first?.status == .ready)
    #expect(first?.summary == "settings.companion.summary")
}
