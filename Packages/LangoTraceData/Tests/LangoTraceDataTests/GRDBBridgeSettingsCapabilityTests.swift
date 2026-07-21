@testable import LangoTraceData
import Testing

@Test("GRDB bridge reports interface language as ready on the real path")
func bridgeReportsInterfaceLanguageAsReady() {
    let capabilities = GRDBLearningContentRepositoryBridge.realPathSettingsCapabilities

    let interfaceLanguage = capabilities.first { $0.kind == .interfaceLanguage }

    #expect(interfaceLanguage != nil)
    #expect(interfaceLanguage?.status == .ready)
}

@Test("GRDB bridge reserves mockOnly for capabilities without a real backend")
func bridgeExposesNoMockOnlyCapability() {
    let capabilities = GRDBLearningContentRepositoryBridge.realPathSettingsCapabilities

    #expect(capabilities.allSatisfy { $0.status != .mockOnly })
}

/// Guard test (green before and after the fix): ordering and metadata must come
/// from the single `SettingsCapabilityCatalog` so the real bridge and the
/// in-memory fixture can never drift apart again. Status is deliberately
/// excluded — the two repositories legitimately differ there.
@Test("Bridge and in-memory capability lists share ordering and metadata")
func bridgeAndMockCatalogShareMetadata() {
    let bridge = GRDBLearningContentRepositoryBridge.realPathSettingsCapabilities
    let mock = InMemoryLearningContentRepository.seeded(spaceID: "en")
        .settingsCapabilities(for: "en")

    #expect(bridge.map(\.kind) == mock.map(\.kind))
    #expect(bridge.map(\.kind) == SettingsCapability.Kind.allCases)
    #expect(bridge.map(\.summary) == mock.map(\.summary))
    #expect(bridge.map(\.detail) == mock.map(\.detail))
    #expect(bridge.map(\.nextRequirement) == mock.map(\.nextRequirement))
    #expect(bridge.map(\.isReadOnly) == mock.map(\.isReadOnly))
}
