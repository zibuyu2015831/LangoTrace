import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Companion memory consent store (LM03-S2b-1)")
struct CompanionMemoryConsentStoreTests {
    @Test("defaultsToNotDecided — no stored value reads as notDecided")
    func defaultsToNotDecided() throws {
        let suiteName = "CompanionMemoryConsent.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCompanionMemoryConsentStore(defaults: defaults)
        #expect(store.consent == .notDecided)
    }

    @Test("threeStatePersists — enabled/disabled persist and reset returns to notDecided")
    func threeStatePersists() throws {
        let suiteName = "CompanionMemoryConsent.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCompanionMemoryConsentStore(defaults: defaults)
        store.consent = .enabled
        #expect(UserDefaultsCompanionMemoryConsentStore(defaults: defaults).consent == .enabled)

        store.consent = .disabled
        #expect(UserDefaultsCompanionMemoryConsentStore(defaults: defaults).consent == .disabled)

        store.reset()
        #expect(store.consent == .notDecided)
    }
}

@Suite("Companion injection gate (LM03-S2b-1 four-state zero-injection)")
struct CompanionInjectionGateTests {
    @Test("notDecidedBlocks — no injection before the one-time preview is decided")
    func notDecidedBlocks() {
        #expect(CompanionInjectionGate.shouldInject(consent: .notDecided, threadUsesProfile: true) == false)
        #expect(CompanionInjectionGate.memoryContext(renderedFacts: ["a"], consent: .notDecided, threadUsesProfile: true).isEmpty)
    }

    @Test("disabledBlocks — global off means never inject")
    func disabledBlocks() {
        #expect(CompanionInjectionGate.shouldInject(consent: .disabled, threadUsesProfile: true) == false)
        #expect(CompanionInjectionGate.memoryContext(renderedFacts: ["a"], consent: .disabled, threadUsesProfile: true).isEmpty)
    }

    @Test("perConversationToggleBlocks — enabled globally but thread toggle off blocks")
    func perConversationToggleBlocks() {
        #expect(CompanionInjectionGate.shouldInject(consent: .enabled, threadUsesProfile: false) == false)
        #expect(CompanionInjectionGate.memoryContext(renderedFacts: ["a"], consent: .enabled, threadUsesProfile: false).isEmpty)
    }

    @Test("enabledAndToggleOnInjects — only this state injects the rendered facts")
    func enabledAndToggleOnInjects() {
        #expect(CompanionInjectionGate.shouldInject(consent: .enabled, threadUsesProfile: true))
        #expect(CompanionInjectionGate.memoryContext(renderedFacts: ["a", "b"], consent: .enabled, threadUsesProfile: true) == ["a", "b"])
    }
}
