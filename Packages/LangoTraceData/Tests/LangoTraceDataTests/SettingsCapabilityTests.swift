@testable import LangoTraceData
import Testing

@Test("Settings capabilities expose interface language without changing learning context")
func settingsCapabilitiesExposeInterfaceLanguageWithoutChangingLearningContext() {
    let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
    let capabilities = repository.settingsCapabilities(for: "en")

    let interfaceLanguage = capabilities.filter { $0.kind == .interfaceLanguage }.first

    #expect(interfaceLanguage != nil)
    #expect(interfaceLanguage?.status == .mockOnly)
    #expect(interfaceLanguage?.summary.contains("跟随系统") == true)
    #expect(interfaceLanguage?.detail.contains("不改变用户母语") == true)
    #expect(interfaceLanguage?.detail.contains("不改变目标语言") == true)
    #expect(interfaceLanguage?.detail.contains("不重写已生成内容") == true)
}
