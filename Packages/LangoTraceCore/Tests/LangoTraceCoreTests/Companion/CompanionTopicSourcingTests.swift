import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Companion topic sourcing consent store (LM03-S2b-2)")
struct CompanionTopicSourcingConsentStoreTests {
    @Test("defaultsToNotDecided — no stored value reads as notDecided")
    func defaultsToNotDecided() throws {
        let suiteName = "CompanionTopicSourcing.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCompanionTopicSourcingConsentStore(defaults: defaults)
        #expect(store.consent == .notDecided)
    }

    @Test("threeStatePersists — enabled/disabled persist and reset returns to notDecided")
    func threeStatePersists() throws {
        let suiteName = "CompanionTopicSourcing.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCompanionTopicSourcingConsentStore(defaults: defaults)
        store.consent = .enabled
        #expect(UserDefaultsCompanionTopicSourcingConsentStore(defaults: defaults).consent == .enabled)
        store.consent = .disabled
        #expect(UserDefaultsCompanionTopicSourcingConsentStore(defaults: defaults).consent == .disabled)
        store.reset()
        #expect(store.consent == .notDecided)
    }
}

@Suite("Companion injection gate — topic sourcing (LM03-S2b-2)")
struct CompanionInjectionGateTopicTests {
    @Test("notDecidedBlocks — no topic sourcing before the one-time preview is decided")
    func notDecidedBlocks() {
        #expect(CompanionInjectionGate.shouldSourceTopic(consent: .notDecided, threadUsesProfile: true) == false)
        #expect(CompanionInjectionGate.broughtInRecords(rendered: ["r"], consent: .notDecided, threadUsesProfile: true).isEmpty)
    }

    @Test("disabledBlocks — global off never sources a topic")
    func disabledBlocks() {
        #expect(CompanionInjectionGate.shouldSourceTopic(consent: .disabled, threadUsesProfile: true) == false)
        #expect(CompanionInjectionGate.broughtInRecords(rendered: ["r"], consent: .disabled, threadUsesProfile: true).isEmpty)
    }

    @Test("perConversationToggleBlocks — enabled globally but thread toggle off blocks")
    func perConversationToggleBlocks() {
        #expect(CompanionInjectionGate.shouldSourceTopic(consent: .enabled, threadUsesProfile: false) == false)
        #expect(CompanionInjectionGate.broughtInRecords(rendered: ["r"], consent: .enabled, threadUsesProfile: false).isEmpty)
    }

    @Test("enabledAndToggleOnSources — only this state brings in the rendered records")
    func enabledAndToggleOnSources() {
        #expect(CompanionInjectionGate.shouldSourceTopic(consent: .enabled, threadUsesProfile: true))
        #expect(CompanionInjectionGate.broughtInRecords(rendered: ["r1"], consent: .enabled, threadUsesProfile: true) == ["r1"])
    }

    @Test("unifiedToggleInvariant — toggle off disables BOTH memory injection and topic sourcing")
    func unifiedToggleInvariant() {
        // The per-conversation toggle (uses_learner_profile) is shared: off → both gates closed.
        #expect(CompanionInjectionGate.shouldInject(consent: .enabled, threadUsesProfile: false) == false)
        #expect(CompanionInjectionGate.shouldSourceTopic(consent: .enabled, threadUsesProfile: false) == false)
    }
}
