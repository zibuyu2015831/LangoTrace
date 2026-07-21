import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

/// LM03-S2a Phase 3: the extraction prompt registry. Asserts the stable id /
/// version / schema version, the structured directive set (privacy boundary +
/// JSON contract), and that the rendered text names the target / native language
/// without concatenating user free text into the instruction region (AI-17).
@Suite("Companion extraction prompt registry")
struct CompanionExtractionPromptRegistryTests {
    @Test("stableIdentityAndSchemaVersion")
    func stableIdentity() {
        #expect(CompanionExtractionPromptRegistry.promptID == "builtin.companion.extraction.v1")
        #expect(CompanionExtractionPromptRegistry.promptVersion == "1")
        #expect(CompanionExtractionPromptRegistry.schemaVersion == "1")
    }

    @Test("carriesPrivacyAndStructuredDirectives")
    func carriesDirectives() {
        let prompt = CompanionExtractionPromptRegistry.extractionPrompt(
            targetLanguageCode: "en", nativeLanguageCode: "zh-Hans"
        )
        #expect(prompt.directives.contains(.groundedInConversationNoFabrication))
        #expect(prompt.directives.contains(.targetLanguageItemsOnly))
        #expect(prompt.directives.contains(.nativeLanguageExplanations))
        #expect(prompt.directives.contains(.structuredJSONOutput))
        #expect(prompt.id == CompanionExtractionPromptRegistry.promptID)
        #expect(prompt.schemaVersion == "1")
    }

    @Test("rendersLanguagesAndStructuredContract")
    func rendersLanguages() {
        let prompt = CompanionExtractionPromptRegistry.extractionPrompt(
            targetLanguageCode: "ja", nativeLanguageCode: "zh-Hans"
        )
        #expect(prompt.text.contains("ja"))
        #expect(prompt.text.contains("zh-Hans"))
        // The structured-output contract names the JSON envelope.
        #expect(prompt.text.contains("schema_version"))
        #expect(prompt.text.contains("candidates"))
    }

    @Test("toleratesMissingNativeLanguage")
    func toleratesMissingNativeLanguage() {
        let prompt = CompanionExtractionPromptRegistry.extractionPrompt(
            targetLanguageCode: "en", nativeLanguageCode: nil
        )
        #expect(prompt.directives.contains(.nativeLanguageExplanations))
        #expect(!prompt.text.isEmpty)
    }
}
