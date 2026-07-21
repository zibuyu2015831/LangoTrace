import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Companion deletion semantics")
struct CompanionDeletionSemanticsTests {
    private func message(_ sequence: Int, id: String) -> CompanionMessage {
        CompanionMessage(
            id: id,
            threadID: "thread",
            sequence: sequence,
            role: sequence.isMultiple(of: 2) ? .user : .assistant,
            content: "m\(sequence)",
            targetLanguageCode: "en",
            createdAt: Date(timeIntervalSince1970: TimeInterval(sequence))
        )
    }

    private var fiveMessages: [CompanionMessage] {
        (0 ..< 5).map { message($0, id: "id-\($0)") }
    }

    @Test("messagesAfterDeletingDropsSubsequent — deletes the target and everything after it")
    func messagesAfterDeletingDropsSubsequent() {
        let result = CompanionConversation.messagesAfterDeleting("id-2", in: fiveMessages)
        #expect(result.map(\.id) == ["id-0", "id-1"])
    }

    @Test("Deleting the first message clears the whole thread")
    func deletingFirstClearsAll() {
        let result = CompanionConversation.messagesAfterDeleting("id-0", in: fiveMessages)
        #expect(result.isEmpty)
    }

    @Test("Deleting an unknown id leaves the thread unchanged")
    func deletingUnknownIsNoOp() {
        let result = CompanionConversation.messagesAfterDeleting("missing", in: fiveMessages)
        #expect(result.map(\.id) == ["id-0", "id-1", "id-2", "id-3", "id-4"])
    }

    @Test("Deleting the last message keeps all earlier ones")
    func deletingLastKeepsEarlier() {
        let result = CompanionConversation.messagesAfterDeleting("id-4", in: fiveMessages)
        #expect(result.map(\.id) == ["id-0", "id-1", "id-2", "id-3"])
    }
}
