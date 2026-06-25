import Foundation
@testable import LangoTraceCore
import Testing

/// Covers the multi-turn conversation value types introduced for the AI Provider
/// multi-turn + streaming enabler (LM03 消费). These are pure value types in
/// Core so the AI package can build requests and future LM03 UI / store can
/// reuse the same transcript model.
@Suite("Conversation message value types")
struct ConversationMessageTests {
    @Test("encodes ordered roles and content round-trip stable")
    func encodesOrderedRolesAndContent() throws {
        let transcript: [ConversationMessage] = [
            ConversationMessage(role: .system, content: "You are grounded."),
            ConversationMessage(role: .user, content: "今天我去公园了。"),
            ConversationMessage(role: .assistant, content: "Nice, tell me more."),
            ConversationMessage(role: .user, content: "It was sunny."),
        ]

        let data = try JSONEncoder().encode(transcript)
        let decoded = try JSONDecoder().decode([ConversationMessage].self, from: data)

        // Order and content must survive a round trip unchanged — the transcript
        // is positional (system → user → assistant → user).
        #expect(decoded == transcript)
        #expect(decoded.map(\.role) == [.system, .user, .assistant, .user])
        #expect(decoded[1].content == "今天我去公园了。")
    }

    @Test("role raw values are stable wire identifiers")
    func roleRawValuesAreStable() {
        #expect(ConversationRole.system.rawValue == "system")
        #expect(ConversationRole.user.rawValue == "user")
        #expect(ConversationRole.assistant.rawValue == "assistant")
        #expect(ConversationRole.allCases.count == 3)
    }
}
