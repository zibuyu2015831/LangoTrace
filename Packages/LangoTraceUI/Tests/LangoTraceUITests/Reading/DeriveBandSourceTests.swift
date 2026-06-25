import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// Covers the LM02-S4b derive() band wiring: a sustained band crossing changes the
/// explanation tier (via hysteresis), a manual override suppresses band, and band
/// feeds ONLY derive() — the AI request's `proficiencyLevelCode` (:95) stays the
/// static seed while `explanationLanguageMode` (:96) follows the band.
@MainActor
@Suite("Derive band source (S4b)")
struct DeriveBandSourceTests {
    private actor RequestRecorder {
        private(set) var requests: [ReadingExplanationRequest] = []
        func record(_ request: ReadingExplanationRequest) {
            requests.append(request)
        }

        func last() -> ReadingExplanationRequest? {
            requests.last
        }
    }

    private func makeStore(
        seedLevel: String = "B1",
        bandLevel: LanguageLevel?,
        explanationAction: @escaping ReadingExplanationAction = { _ in throw StubError() }
    ) -> ReadingDocumentStore {
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            targetLanguageCode: "en",
            proficiencyLevelCode: seedLevel,
            explanationAction: explanationAction,
            ttsAction: { _ in .cancelled }
        )
        store.reconnectBandSource { _, _ in bandLevel }
        return store
    }

    private struct StubError: Error {}

    @Test("a sustained band crossing changes the explanation tier")
    func sustainedBandCrossingChangesTier() async {
        // Seed B1 → bilingualBridge; band says A2 → sourceLanguage, sustained.
        let store = makeStore(bandLevel: .a2)
        #expect(store.currentExplanationMode == .bilingualBridge)
        await store.evaluateBandForDocumentOpen()
        await store.evaluateBandForDocumentOpen()
        #expect(store.currentExplanationMode == .bilingualBridge) // < threshold
        await store.evaluateBandForDocumentOpen()
        #expect(store.currentExplanationMode == .sourceLanguage) // 3rd → switches
    }

    @Test("a manual override suppresses band suggestions for the document")
    func userOverrideSuppressesBandSuggestionForDocument() async {
        let store = makeStore(bandLevel: .a2)
        store.switchExplanationMode(.targetImmersion) // user picks immersion
        for _ in 0 ..< 5 {
            await store.evaluateBandForDocumentOpen()
        }
        // Band wanted sourceLanguage, but the manual override wins.
        #expect(store.currentExplanationMode == .targetImmersion)
    }

    @Test("band feeds only derive: AI request keeps the static proficiency, mode follows band")
    func bandOnlyFeedsDeriveNotAIRequests() async {
        let recorder = RequestRecorder()
        let store = makeStore(
            bandLevel: .a2,
            explanationAction: { request in
                await recorder.record(request)
                throw StubError()
            }
        )
        // Drive the band to switch the tier to sourceLanguage.
        for _ in 0 ..< 3 {
            await store.evaluateBandForDocumentOpen()
        }
        #expect(store.currentExplanationMode == .sourceLanguage)

        store.selectText("word", sentenceID: "s1")
        store.explainSelection()
        // Allow the explanation task to run.
        try? await Task.sleep(for: .milliseconds(50))

        let request = await recorder.last()
        // :96 explanationLanguageMode follows the band...
        #expect(request?.explanationLanguageMode == .sourceLanguage)
        // ...but :95 proficiencyLevelCode is still the static seed (band never flows here).
        #expect(request?.proficiencyLevelCode == "B1")
    }
}
