import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Companion conversation projection (LM03-S2b-1 honest disclosure)")
struct CompanionConversationProjectionTests {
    private func projection(injecting: Bool, records: Bool = false) -> AIRequestPreviewProjection {
        .companionConversation(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            lengthBucket: .medium,
            hasMemoryInjection: injecting,
            hasBroughtInRecords: records
        )
    }

    @Test("withBroughtInRecords — discloses broughtInRecords; longTermMemory still excluded")
    func withBroughtInRecords() {
        let p = projection(injecting: false, records: true)
        #expect(p.includedContent.contains(.broughtInRecords))
        #expect(p.excludedContent.contains(.longTermMemory))
        #expect(!p.includedContent.contains(.curatedLearnerMemory))
    }

    @Test("withoutBroughtInRecords — no broughtInRecords disclosed")
    func withoutBroughtInRecords() {
        #expect(!projection(injecting: false, records: false).includedContent.contains(.broughtInRecords))
    }

    @Test("withInjection — discloses curatedLearnerMemory but keeps longTermMemory excluded")
    func withInjection() {
        let p = projection(injecting: true)
        #expect(p.capability == .companionConversation)
        #expect(p.includedContent.contains(.curatedLearnerMemory))
        #expect(p.includedContent.contains(.companionConversation))
        // The raw long-term memory store stays globally excluded — only the
        // curated subset is disclosed as sent.
        #expect(p.excludedContent.contains(.longTermMemory))
        #expect(!p.includedContent.contains(.longTermMemory))
        // Other always-excluded guarantees intact.
        for guarded in [AIRequestContentDescriptor.photoAttachments, .audioRecordings, .historicalEntries, .otherLanguageSpaces, .apiCredential] {
            #expect(p.excludedContent.contains(guarded))
        }
    }

    @Test("withoutInjection — no curatedLearnerMemory, longTermMemory still excluded")
    func withoutInjection() {
        let p = projection(injecting: false)
        #expect(!p.includedContent.contains(.curatedLearnerMemory))
        #expect(p.excludedContent.contains(.longTermMemory))
        #expect(p.includedContent.contains(.companionConversation))
    }
}
