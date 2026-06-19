import Foundation
@testable import LangoTraceUI
import Testing

/// Structural guards for the bilingual reading route across the three platforms and for the
/// self-review decision (P1-3) that the reading page reads the LIVE rendering rather than a
/// snapshotted route seed.
@Suite("Entry reading routing structure")
struct EntryReadingRoutingStructureTests {
    @Test("All three platform route enums carry an entry-id-only bilingual reading case")
    func routeEnumsCarryBilingualReading() throws {
        for fileName in ["PhoneRoute.swift", "PadMainModels.swift", "MacMainModels.swift"] {
            let source = try source(named: fileName)
            #expect(source.contains("case bilingualReading(String)"), "\(fileName) missing bilingualReading route")
        }
    }

    @Test("Reading store view reads the live rendering from the store, not a route snapshot")
    func readingStoreUsesLiveRendering() throws {
        let source = try source(named: "EntryReadingViews.swift")

        #expect(source.contains("EntryReadingPresentation.make(from: contentStore.rendering(for: entry))"))
        #expect(source.contains("await contentStore.stopSentenceSequence()"))
        // The reading route must not snapshot sentences into a seed.
        #expect(!source.contains("EntryReadingRouteSeed"))
    }

    @Test("Detail page opens the reading route through an explicit affordance")
    func detailOpensReadingRoute() throws {
        let supportingViews = try source(named: "PhoneMainSupportingViews.swift")

        #expect(supportingViews.contains("onOpenReading"))
        #expect(supportingViews.contains(#"localizedText("entry.reading.open")"#))
    }

    private func source(named fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EntryReading/
            .deletingLastPathComponent() // LangoTraceUITests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // LangoTraceUI/ (package root)
            .appendingPathComponent("Sources/LangoTraceUI")
            .appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
