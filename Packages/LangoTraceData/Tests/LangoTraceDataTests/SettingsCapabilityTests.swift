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
