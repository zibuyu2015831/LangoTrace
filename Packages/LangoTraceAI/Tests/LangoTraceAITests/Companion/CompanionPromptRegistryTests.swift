import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Companion prompt registry")
struct CompanionPromptRegistryTests {
    private func prompt(
        persona: CompanionPersona = .default,
        seed: String? = nil
    ) -> CompanionRenderedPrompt {
        CompanionPromptRegistry.systemPrompt(
            persona: persona,
            targetLanguageCode: "en",
            nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1",
            seedEntryBody: seed
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
}
