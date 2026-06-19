import Foundation
@testable import LangoTraceUI
import Testing

@Suite("ReadingTTSOutcome")
struct ReadingTTSOutcomeTests {
    @Test("TTS action returns success outcome when action resolves successfully")
    func ttsActionReturnSuccessOutcome() async {
        let successAction: ReadingTTSAction = { _ in .success }
        let request = ReadingTTSRequest(
            documentID: "doc1",
            spaceID: "space1",
            sentenceID: "s1",
            text: "Hello",
            targetLanguageCode: "en"
        )
        let outcome = await successAction(request)
        #expect(outcome == .success)
    }

    @Test("TTS action returns failed outcome with displayable message")
    func ttsActionReturnFailedOutcome() async {
        let failedAction: ReadingTTSAction = { _ in .failed("No provider configured") }
        let request = ReadingTTSRequest(
            documentID: "doc1",
            spaceID: "space1",
            sentenceID: "s1",
            text: "Hello",
            targetLanguageCode: "en"
        )
        let outcome = await failedAction(request)
        if case let .failed(message) = outcome {
            #expect(!message.isEmpty)
        } else {
            Issue.record("expected .failed outcome")
        }
    }

    @Test("TTS action returns cancelled outcome when cancelled")
    func ttsActionReturnCancelledOutcome() async {
        let cancelledAction: ReadingTTSAction = { _ in .cancelled }
        let request = ReadingTTSRequest(
            documentID: "doc1",
            spaceID: "space1",
            sentenceID: "s1",
            text: "Hello",
            targetLanguageCode: "en"
        )
        let outcome = await cancelledAction(request)
        #expect(outcome == .cancelled)
    }

    @Test("TTS failure outcome is not equal to cancelled")
    func ttsFailureIsNotCancelled() {
        let failed = ReadingTTSOutcome.failed("error")
        #expect(failed != .cancelled)
        #expect(failed != .success)
    }
}
