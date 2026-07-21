import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// Covers the LM02-S4a lookup-capture埋点 on the reading explanation seam: a user
/// explanation request fires the capture with the looked-up term (the behaviour
/// signal), and the capture carries no AI explanation content.
@MainActor
@Suite("Reading lookup capture")
struct ReadingLookupCaptureTests {
    private final class Recorder: @unchecked Sendable {
        var inputs: [ReadingLookupCaptureInput] = []
    }

    private struct StubError: Error {}

    private func makeStore(capture: @escaping ReadingLookupCaptureAction) -> ReadingDocumentStore {
        ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            proficiencyLevelCode: "B1",
            // Capture fires synchronously before the (async) explanation; the
            // explanation outcome is irrelevant to this test.
            explanationAction: { _ in throw StubError() },
            ttsAction: { _ in .cancelled },
            lookupCaptureAction: capture
        )
    }

    @Test("requesting an explanation fires the lookup capture with the term")
    func explainSelectionFiresCapture() {
        let recorder = Recorder()
        let store = makeStore(capture: { recorder.inputs.append($0) })
        store.selectText("ephemeral", sentenceID: "s1")
        store.explainSelection()

        #expect(recorder.inputs.count == 1)
        let input = try? #require(recorder.inputs.first)
        #expect(input?.lookedUpTerm == "ephemeral")
        #expect(input?.spaceID == "space-1")
        #expect(input?.documentID == "doc-1")
    }

    @Test("no selection means no capture")
    func noSelectionNoCapture() {
        let recorder = Recorder()
        let store = makeStore(capture: { recorder.inputs.append($0) })
        store.explainSelection()
        #expect(recorder.inputs.isEmpty)
    }
}
