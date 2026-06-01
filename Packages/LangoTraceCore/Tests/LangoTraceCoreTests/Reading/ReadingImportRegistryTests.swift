import Testing
@testable import LangoTraceCore

@Suite("Reading import registry")
struct ReadingImportRegistryTests {
    @Test("vertical slice registry only registers pasted text txt and markdown")
    func verticalSliceRegistryHasExplicitAdapters() {
        let registry = ReadingImportFormatRegistry.verticalSliceDefaults()

        #expect(registry.adapter(for: .pastedText)?.id == "pasted-text.v1")
        #expect(registry.adapter(forFileExtension: "txt")?.id == "plain-text-file.v1")
        #expect(registry.adapter(forFileExtension: "md")?.id == "markdown-file.v1")
        #expect(registry.adapter(forFileExtension: "epub") == nil)
        #expect(registry.adapter(forFileExtension: "pdf") == nil)
    }

    @Test("future adapters are represented without enabling them")
    func futureAdaptersAreDocumentedButDisabled() {
        let disabled = ReadingImportFormatRegistry.futureAdapterDescriptors()

        #expect(disabled.contains { $0.id == "epub-text-extraction.v1" && $0.status == .future })
        #expect(disabled.contains { $0.id == "pdf-text-extraction.v1" && $0.status == .future })
        #expect(disabled.contains { $0.id == "html-clip.v1" && $0.status == .future })
    }
}
