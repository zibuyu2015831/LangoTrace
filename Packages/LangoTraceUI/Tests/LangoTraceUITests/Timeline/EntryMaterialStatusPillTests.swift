import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("materialStatus pure function")
struct EntryMaterialStatusPillTests {
    // MARK: - Fixtures

    private func makeEntry(body: String = "今天我去了咖啡馆。") -> LearningEntry {
        LearningEntry(
            id: "e1",
            spaceID: "s1",
            title: "Coffee",
            body: body,
            source: .typedText,
            scene: "生活",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func makeRendering(entry: LearningEntry, sentenceCount: Int = 2, useStaleHash: Bool = false) -> LearningRendering {
        let hash = useStaleHash ? "stale-hash-000" : LearningMaterialTextHash.sha256(for: entry.body)
        let sentences = (0..<sentenceCount).map { i in
            RenderingSentence(id: "s\(i)", translation: "Trans", targetText: "Target", note: "")
        }
        return LearningRendering(
            id: "m1",
            entryID: entry.id,
            targetText: "Learning text",
            promptLabel: "prompt",
            providerLabel: "gpt-4o",
            isMock: false,
            sourceEntryBodyHash: hash,
            sentences: sentences
        )
    }

    // MARK: - noMaterial

    @Test("materialStatus returns noMaterial when rendering is nil")
    func noRenderingReturnsNoMaterial() {
        let entry = makeEntry()
        #expect(materialStatus(entry: entry, rendering: nil) == .noMaterial)
    }

    // MARK: - stale

    @Test("materialStatus returns stale when sourceEntryBodyHash does not match current body hash")
    func mismatchedHashReturnsStale() {
        let entry = makeEntry()
        let rendering = makeRendering(entry: entry, sentenceCount: 3, useStaleHash: true)
        #expect(materialStatus(entry: entry, rendering: rendering) == .stale(sentenceCount: 3))
    }

    @Test("stale preserves sentence count from rendering")
    func stalePreservesSentenceCount() {
        let entry = makeEntry()
        let rendering = makeRendering(entry: entry, sentenceCount: 5, useStaleHash: true)
        if case .stale(let count) = materialStatus(entry: entry, rendering: rendering) {
            #expect(count == 5)
        } else {
            Issue.record("Expected .stale but got different status")
        }
    }

    // MARK: - fresh

    @Test("materialStatus returns fresh when sourceEntryBodyHash matches current body hash")
    func matchingHashReturnsFresh() {
        let entry = makeEntry()
        let rendering = makeRendering(entry: entry, sentenceCount: 2)
        #expect(materialStatus(entry: entry, rendering: rendering) == .fresh(sentenceCount: 2))
    }

    @Test("fresh preserves sentence count from rendering")
    func freshPreservesSentenceCount() {
        let entry = makeEntry()
        let rendering = makeRendering(entry: entry, sentenceCount: 7)
        if case .fresh(let count) = materialStatus(entry: entry, rendering: rendering) {
            #expect(count == 7)
        } else {
            Issue.record("Expected .fresh but got different status")
        }
    }

    @Test("hash is recomputed from current entry body, not cached")
    func hashRecomputedFromCurrentBody() {
        let entry = makeEntry(body: "hello")
        let hashForHello = LearningMaterialTextHash.sha256(for: "hello")
        let rendering = LearningRendering(
            id: "m1", entryID: entry.id, targetText: "Hello",
            promptLabel: "p", providerLabel: "m", isMock: false,
            sourceEntryBodyHash: hashForHello, sentences: []
        )
        #expect(materialStatus(entry: entry, rendering: rendering) == .fresh(sentenceCount: 0))
    }
}
