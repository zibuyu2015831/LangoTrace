import Foundation

/// A single parsed server-sent event from an OpenAI-compatible streaming
/// response. The transport produces an ordered sequence of these; the streaming
/// service maps `.data` payloads to text deltas and stops on `.done`.
enum ServerSentEvent: Equatable {
    /// A `data:` line payload (the JSON chunk body, prefix stripped).
    case data(String)
    /// The `data: [DONE]` terminator.
    case done
}

/// Incremental, byte-level SSE line parser.
///
/// Works on raw bytes and splits **only** on newline (`0x0A`). UTF-8 never
/// embeds `0x0A` inside a multibyte sequence, so a complete line is always
/// safely decodable — this is what lets the parser survive both half-lines and
/// multibyte characters split across network chunk boundaries. Incomplete
/// trailing bytes stay buffered until the next chunk completes the line.
struct ServerSentEventParser {
    private var buffer: [UInt8] = []

    /// Feeds the next chunk of response bytes and returns any events whose lines
    /// are now complete. Partial trailing bytes are retained for the next call.
    mutating func consume(_ bytes: [UInt8]) -> [ServerSentEvent] {
        buffer.append(contentsOf: bytes)
        var events: [ServerSentEvent] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineBytes = Array(buffer[..<newlineIndex])
            buffer.removeSubrange(...newlineIndex)
            if let event = Self.event(fromLineBytes: lineBytes) {
                events.append(event)
            }
        }
        return events
    }

    private static func event(fromLineBytes lineBytes: [UInt8]) -> ServerSentEvent? {
        // Strip an optional trailing CR (servers may send CRLF).
        var bytes = lineBytes
        if bytes.last == 0x0D {
            bytes.removeLast()
        }
        guard let line = String(bytes: bytes, encoding: .utf8) else {
            return nil
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Blank lines separate events; comment lines start with ':'. Only
        // `data:` fields carry payload for this transport.
        guard trimmed.hasPrefix("data:") else {
            return nil
        }
        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" {
            return .done
        }
        return .data(payload)
    }
}

/// Pure extraction of the incremental text content delta from an
/// OpenAI-compatible streaming `data:` payload.
enum OpenAIStreamDeltaExtractor {
    /// Extracts `choices[0].delta.content` from a chat/completions stream chunk,
    /// returning `nil` for chunks that carry no text (e.g. the role-only opening
    /// chunk or finish-reason-only closing chunk).
    static func chatCompletionsContentDelta(fromDataPayload payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty
        else {
            return nil
        }
        return content
    }

    /// Extracts the text delta from an OpenAI Responses API stream event payload
    /// (`response.output_text.delta`), returning `nil` for non-text events.
    static func responsesContentDelta(fromDataPayload payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        // Responses API streams typed events; the text deltas arrive as
        // `{"type":"response.output_text.delta","delta":"..."}`.
        if let type = object["type"] as? String,
           type == "response.output_text.delta",
           let delta = object["delta"] as? String,
           !delta.isEmpty
        {
            return delta
        }
        return nil
    }
}
