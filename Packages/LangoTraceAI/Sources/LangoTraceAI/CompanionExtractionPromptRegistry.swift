import Foundation
import LangoTraceCore

/// Typed marker for a directive embedded in the companion extraction prompt.
/// Carrying these as a structured set (rather than string-matching the prompt
/// text) makes the privacy boundary and the structured-output contract
/// **structurally verifiable** and not brittle against wording changes — mirroring
/// `CompanionPromptDirective`.
public enum CompanionExtractionDirective: Equatable, Hashable, Sendable {
    /// Only extract items that actually appear in the provided conversation; never
    /// invent vocabulary or infer facts about the user (AI-17 hardening + privacy
    /// boundary: the model is given conversation content, not a license to profile).
    case groundedInConversationNoFabrication
    /// Extract target-language vocabulary / expressions worth reviewing.
    case targetLanguageItemsOnly
    /// Explanations and example glosses are written in the learner's native language.
    case nativeLanguageExplanations
    /// The response must be the fixed JSON object — nothing else.
    case structuredJSONOutput
}

/// A rendered companion extraction prompt: the assembled text plus the typed
/// directive set and the schema version it targets.
public struct CompanionExtractionRenderedPrompt: Equatable, Sendable {
    public var id: String
    public var version: String
    public var schemaVersion: String
    public var text: String
    public var directives: Set<CompanionExtractionDirective>

    public init(
        id: String,
        version: String,
        schemaVersion: String,
        text: String,
        directives: Set<CompanionExtractionDirective>
    ) {
        self.id = id
        self.version = version
        self.schemaVersion = schemaVersion
        self.text = text
        self.directives = directives
    }
}

/// Builds the companion chat extraction system prompt (LM03-S2a). Pure function of
/// vetted inputs — the conversation content is supplied as separate transcript
/// turns (reference content), never concatenated into the instruction region
/// (AI-17). Mirrors `CompanionPromptRegistry` / `LearningMaterialPromptRegistry`.
public enum CompanionExtractionPromptRegistry {
    public static let promptID = "builtin.companion.extraction.v1"
    public static let promptVersion = "1"
    public static let schemaVersion = "1"

    /// Registered structured-output schema name (mirrors the learning-material
    /// schema-name convention used by `structuredCompletionBody`).
    public static let schemaName = "companion_memory_candidates"

    public static func extractionPrompt(
        targetLanguageCode: String,
        nativeLanguageCode: String?
    ) -> CompanionExtractionRenderedPrompt {
        let directives: Set<CompanionExtractionDirective> = [
            .groundedInConversationNoFabrication,
            .targetLanguageItemsOnly,
            .nativeLanguageExplanations,
            .structuredJSONOutput,
        ]
        let native = nativeLanguageCode ?? "the learner's native language"
        let lines = [
            "You extract reusable vocabulary and expressions from a language-practice "
                + "conversation between a learner and their companion.",
            "Extract only \(targetLanguageCode) words / phrases / sentence patterns / "
                + "grammar points / error patterns that actually appear in the conversation "
                + "below and are worth reviewing. Do not invent items that are not present, "
                + "and do not infer or output any personal facts about the learner — you are "
                + "mining language, not profiling the person.",
            "Write every explanation and the native-language gloss of each example in "
                + "\(native). Keep the target-language example in \(targetLanguageCode).",
            "Respond with ONLY a single JSON object of this shape, and nothing else:\n"
                + "{\"schema_version\":\"\(schemaVersion)\",\"candidates\":["
                + "{\"kind\":\"word|phrase|sentencePattern|grammarPoint|errorPattern\","
                + "\"text\":\"...\",\"explanation_native\":\"...\","
                + "\"example_target\":\"...\",\"example_native\":\"...\"}]}",
            "If the conversation contains nothing worth extracting, return an empty "
                + "\"candidates\" array.",
        ]
        return CompanionExtractionRenderedPrompt(
            id: promptID,
            version: promptVersion,
            schemaVersion: schemaVersion,
            text: lines.joined(separator: "\n\n"),
            directives: directives
        )
    }
}
