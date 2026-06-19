import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading explanation mode switch (Phase 4)", .serialized)
struct ReadingExplanationModeSwitchTests {
    // MARK: - switchExplanationMode without a selection

    @Test("switchExplanationMode updates currentExplanationMode without selection")
    func switchModeNoSelection() {
        let store = makeStore(level: "A1")
        #expect(store.currentExplanationMode == .sourceLanguage)
        store.switchExplanationMode(.targetImmersion)
        #expect(store.currentExplanationMode == .targetImmersion)
    }

    @Test("switchExplanationMode to same mode is a no-op")
    func switchModeToSameIsNoOp() async {
        let explanation = CapturingReadingExplanationAction()
        let store = makeStore(level: "B2", explanationAction: explanation.explain)
        store.selectText("word", sentenceID: "s1")
        store.explainSelection()
        await explanation.waitForRequestCount(1)

        let countBefore = await explanation.requests.count
        store.switchExplanationMode(.bilingualBridge)
        try? await Task.sleep(for: .milliseconds(50))
        let countAfter = await explanation.requests.count
        #expect(countAfter == countBefore)
    }

    // MARK: - switchExplanationMode with an active selection re-issues request

    @Test("switchExplanationMode with selection triggers new explanation request")
    func switchModeWithSelectionTriggersRequest() async {
        let explanation = CapturingReadingExplanationAction()
        let store = makeStore(level: "A1", explanationAction: explanation.explain)
        store.selectText("reading", sentenceID: "s1")

        store.switchExplanationMode(.bilingualBridge)
        await explanation.waitForRequestCount(1)

        let request = await explanation.requests.last
        #expect(request?.explanationLanguageMode == .bilingualBridge)
        #expect(store.currentExplanationMode == .bilingualBridge)
    }

    @Test("switching mode back to cached mode is a cache hit — no new request")
    func switchModeBackToCachedHitsCache() async {
        let explanation = CapturingReadingExplanationAction()
        let store = makeStore(level: "B1", explanationAction: explanation.explain)
        store.selectText("context", sentenceID: "s1")

        // First explain at bilingualBridge (default for B1)
        store.explainSelection()
        await explanation.waitForRequestCount(1)
        #expect(store.explanationSource != .cache)

        // Switch to sourceLanguage — new request
        store.switchExplanationMode(.sourceLanguage)
        await explanation.waitForRequestCount(2)

        // Switch back to bilingualBridge — should hit cache
        store.switchExplanationMode(.bilingualBridge)
        try? await Task.sleep(for: .milliseconds(50))
        let total = await explanation.requests.count
        #expect(total == 2) // no third request
        #expect(store.explanationSource == .cache)
    }

    // MARK: - replaceDocument resets mode to Level-derived default

    @Test("replaceDocument resets currentExplanationMode to Level-derived default")
    func replaceDocumentResetsMode() {
        let store = makeStore(level: "C1")
        #expect(store.currentExplanationMode == .targetImmersion)
        store.switchExplanationMode(.sourceLanguage)
        #expect(store.currentExplanationMode == .sourceLanguage)
        store.replaceDocument(documentID: "doc-2", spaceID: "space-1")
        #expect(store.currentExplanationMode == .targetImmersion)
    }

    // MARK: - Helpers

    private func makeStore(
        level: String = "B2",
        explanationAction: @escaping ReadingExplanationAction = { _ in .modeTestSample() }
    ) -> ReadingDocumentStore {
        ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            proficiencyLevelCode: level,
            explanationAction: explanationAction,
            ttsAction: { _ in .cancelled }
        )
    }
}

// MARK: - Private test helpers

private actor CapturingReadingExplanationAction {
    private(set) var requests: [ReadingExplanationRequest] = []

    func explain(_ request: ReadingExplanationRequest) async throws -> ReadingSelectionExplanationResult {
        requests.append(request)
        return .modeTestSample()
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await Task.yield()
        }
    }
}

private extension ReadingSelectionExplanationResult {
    static func modeTestSample() -> ReadingSelectionExplanationResult {
        ReadingSelectionExplanationResult(
            schemaVersion: "reading_selection_explanation.v3",
            selection: "word",
            shortExplanation: "Explanation",
            meaningInNativeLanguage: "释义",
            usageNote: "Usage note.",
            exampleSentence: "Example sentence."
        )
    }
}
