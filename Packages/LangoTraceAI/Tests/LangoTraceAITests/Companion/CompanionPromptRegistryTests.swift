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
        broughtInRecords: [String] = [],
        styleDescriptor: CompanionStyleDescriptor? = nil
    ) -> CompanionRenderedPrompt {
        CompanionPromptRegistry.systemPrompt(
            persona: persona,
            targetLanguageCode: "en",
            nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1",
            seedEntryBody: seed,
            memoryContext: memoryContext,
            broughtInRecords: broughtInRecords,
            styleDescriptor: styleDescriptor
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

    @Test("Warm-recast persona renders its instruction fragment into the prompt text (S3a opt-in)")
    func warmRecastFragmentRenderedInText() {
        // The directive set already encodes the posture; assert the actual
        // instruction text reaches the model so the opt-in genuinely takes effect.
        let recast = prompt(persona: CompanionPersona(tone: .friendly, formality: .casual, correction: .warmRecast))
        #expect(recast.text.contains("naturally"))
        #expect(recast.text.contains("restate the correct form"))
        // The default (ifNeeded) posture must NOT emit the recast wording.
        let ifNeeded = prompt(persona: .default)
        #expect(!ifNeeded.text.contains("restate the correct form in your own reply"))
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

    @Test("Style-grounded directive + register/ceiling appear only when a style descriptor is supplied (LM03-S4a)")
    func styleInjectionOnlyWhenDescriptorPresent() {
        // No descriptor → no directive, no STYLE block (S1/S3b parity).
        let none = prompt(styleDescriptor: nil)
        #expect(!none.directives.contains(.styleGroundedPersona))
        #expect(!none.text.contains("STYLE"))
        #expect(!none.text.contains("register"))

        // Descriptor → directive present; register is mirrored and complexity is
        // capped at the band ceiling (i+1 down-projection), framed as reference.
        let injected = prompt(styleDescriptor: CompanionStyleDescriptor(
            formality: .casual, nativeElaboration: .elaborate, complexityCeiling: .a2
        ))
        #expect(injected.directives.contains(.styleGroundedPersona))
        #expect(injected.text.contains("casual register"))
        #expect(injected.text.contains("elaborate"))
        // The band ceiling (A2) caps complexity even though native style is elaborate.
        #expect(injected.text.contains("A2"))
        #expect(injected.text.contains("never push"))
        #expect(injected.text.contains("not an instruction"))
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
