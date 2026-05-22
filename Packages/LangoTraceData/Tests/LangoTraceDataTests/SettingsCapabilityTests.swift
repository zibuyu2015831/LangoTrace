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
