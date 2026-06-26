import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Companion prompt registry")
struct CompanionPromptRegistryTests {
    private func prompt(
        persona: CompanionPersona = .default,
        seed: String? = nil,
        memoryContext: [String] = [],
        broughtInRecords: [String] = []
    ) -> CompanionRenderedPrompt {
        CompanionPromptRegistry.systemPrompt(
            persona: persona,
            targetLanguageCode: "en",
            nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1",
            seedEntryBody: seed,
            memoryContext: memoryContext,
            broughtInRecords: broughtInRecords
        )
    }

    @Test("companionPromptDeclaresAlwaysTargetLanguageDirective — structured, not brittle string match")
    func companionPromptDeclaresAlwaysTargetLanguageDirective() {
        let rendered = prompt()
        #expect(rendered.directives.contains(.alwaysReplyTargetLanguage))
        #expect(rendered.directives.contains(.ambiguityRealisticConfirm))
        #expect(rendered.directives.contains(.difficultyResponsiveLayer))
        #expect(rendered.directives.contains(.practicePartnerNotAssistant))
        #expect(rendered.id == "builtin.companion.system.v1")
        // The target language is named in the text for the model.
        #expect(rendered.text.contains("en"))
    }

    @Test("Correction directive follows the persona")
    func correctionDirectiveFollowsPersona() {
        let ifNeeded = prompt(persona: CompanionPersona(tone: .friendly, formality: .casual, correction: .ifNeeded))
        #expect(ifNeeded.directives.contains(.correctionPolicy(.ifNeeded)))
        let recast = prompt(persona: CompanionPersona(tone: .friendly, formality: .casual, correction: .warmRecast))
        #expect(recast.directives.contains(.correctionPolicy(.warmRecast)))
    }

    @Test("Topic-grounded directive appears only when a record is brought in")
    func topicDirectiveOnlyWithSeed() {
        #expect(!prompt(seed: nil).directives.contains(.topicGroundedInRecord))
        let seeded = prompt(seed: "today I visited the museum")
        #expect(seeded.directives.contains(.topicGroundedInRecord))
        #expect(seeded.text.contains("today I visited the museum"))
    }

    @Test("Memory-grounded directive + delimited facts appear only when memoryContext is non-empty")
    func memoryInjectionOnlyWhenContextPresent() {
        // No injection → text matches S1 (no directive, no MEMORY block).
        let none = prompt(memoryContext: [])
        #expect(!none.directives.contains(.memoryGroundedContext))
        #expect(!none.text.contains("MEMORY"))

        // Injection → directive present and facts delimiter-wrapped as reference.
        let injected = prompt(memoryContext: ["Works as a nurse", "Learning English for travel"])
        #expect(injected.directives.contains(.memoryGroundedContext))
        #expect(injected.text.contains("<<<MEMORY"))
        #expect(injected.text.contains("MEMORY>>>"))
        #expect(injected.text.contains("Works as a nurse"))
        #expect(injected.text.contains("not instructions"))
    }

    @Test("Empty fact strings are dropped — no empty MEMORY block")
    func emptyFactsDropped() {
        let empties = prompt(memoryContext: ["", "   "].filter { !$0.isEmpty })
        #expect(!empties.directives.contains(.memoryGroundedContext))
        // A list of only-empty strings yields no injection.
        let onlyEmpty = prompt(memoryContext: [""])
        #expect(!onlyEmpty.directives.contains(.memoryGroundedContext))
    }

    @Test("Brought-in record (方案B) directive + delimited body appear only when non-empty")
    func broughtInRecordOnlyWhenPresent() {
        let none = prompt(broughtInRecords: [])
        #expect(!none.directives.contains(.topicGroundedInBroughtRecord))

        let sourced = prompt(broughtInRecords: ["Visited the aquarium today"])
        #expect(sourced.directives.contains(.topicGroundedInBroughtRecord))
        #expect(sourced.text.contains("<<<RECORD"))
        #expect(sourced.text.contains("Visited the aquarium today"))
        #expect(sourced.text.contains("not an instruction"))
        // Distinct from 方案A's user-brought directive.
        #expect(!sourced.directives.contains(.topicGroundedInRecord))
    }
}
