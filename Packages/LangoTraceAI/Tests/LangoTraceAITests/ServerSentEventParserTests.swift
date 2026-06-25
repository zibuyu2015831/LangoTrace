import Foundation
@testable import LangoTraceAI
import Testing

/// Phase 0 spike-gate coverage: the pure SSE line parser must produce ordered
/// `data:` deltas, terminate on `[DONE]`, and survive lines split across chunk
/// boundaries (including multi-byte UTF-8 split mid-character). Works on raw
/// bytes so a newline (0x0A) is the only split token — UTF-8 never embeds 0x0A
/// inside a multibyte sequence, so decoding complete lines is always safe.
@Suite("Server-sent event parser")
struct ServerSentEventParserTests {
    private func events(feeding chunks: [String]) -> [ServerSentEvent] {
        var parser = ServerSentEventParser()
        var out: [ServerSentEvent] = []
        for chunk in chunks {
            out.append(contentsOf: parser.consume(Array(chunk.utf8)))
        }
        return out
    }

    @Test("yields ordered data payloads and terminates on [DONE]")
    func yieldsOrderedDeltasAndTerminatesOnDone() {
        let stream = """
        data: {"a":1}
        data: {"b":2}
        data: [DONE]

        """
        let result = events(feeding: [stream])
        #expect(result == [.data("{\"a\":1}"), .data("{\"b\":2}"), .done])
    }

    @Test("buffers a line split across two chunks")
    func buffersHalfLineAcrossChunks() {
        // The first `data:` line is cut in half between two network chunks.
        let result = events(feeding: ["data: {\"hel", "lo\":1}\ndata: [DONE]\n"])
        #expect(result == [.data("{\"hello\":1}"), .done])
    }

    @Test("buffers a multi-byte UTF-8 character split across two chunks")
    func buffersMultibyteCharacterAcrossChunks() throws {
        // "今" is 3 bytes (E4 BB 8A); split it between two chunks. A byte-level
        // parser that only splits on 0x0A reassembles the character correctly.
        let full = "data: {\"c\":\"今\"}\n"
        let bytes = Array(full.utf8)
        let splitIndex = try #require(bytes.firstIndex(of: 0xBB)) // middle byte of 今
        var parser = ServerSentEventParser()
        var out: [ServerSentEvent] = []
        out.append(contentsOf: parser.consume(Array(bytes[..<splitIndex])))
        out.append(contentsOf: parser.consume(Array(bytes[splitIndex...])))
        #expect(out == [.data("{\"c\":\"今\"}")])
    }

    @Test("ignores blank lines and non-data fields")
    func ignoresBlankAndNonDataLines() {
        let stream = """
        : keep-alive comment

        event: message
        data: {"x":1}

        data: [DONE]

        """
        #expect(events(feeding: [stream]) == [.data("{\"x\":1}"), .done])
    }

    @Test("extracts chat/completions content delta from a data payload")
    func extractsChatCompletionsDelta() {
        let payload = "{\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}"
        #expect(OpenAIStreamDeltaExtractor.chatCompletionsContentDelta(fromDataPayload: payload) == "Hel")
    }

    @Test("returns nil for a chat/completions chunk with no content delta")
    func nilForRoleOnlyDelta() {
        let payload = "{\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}"
        #expect(OpenAIStreamDeltaExtractor.chatCompletionsContentDelta(fromDataPayload: payload) == nil)
    }
}
