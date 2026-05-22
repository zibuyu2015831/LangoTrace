import Foundation
import LangoTraceCore

public struct LearningMaterialRenderedPrompt: Equatable, Sendable {
    public var id: String
    public var version: String
    public var system: String
    public var user: String

    public init(id: String, version: String, system: String, user: String) {
        self.id = id
        self.version = version
        self.system = system
        self.user = user
    }
}

public enum LearningMaterialPromptRegistry {
    public static let generationPromptID = "builtin.learning_material.generate.v1"
    public static let analysisPromptID = "builtin.learning_material.analyze_current_text.v1"
    public static let promptVersion = "1"
    public static let schemaVersion = "learning_material.v1"

    public static func generatePrompt(
        input: LearningMaterialGenerationInput,
        lengthBucket: LearningMaterialEstimatedTokenBucket
    ) -> LearningMaterialRenderedPrompt {
        LearningMaterialRenderedPrompt(
            id: generationPromptID,
            version: promptVersion,
            system: generationSystemPrompt,
            user: """
            task: generate_learning_material
            schema_version: \(schemaVersion)
            native_language_code: \(input.nativeLanguageCode)
            target_language_code: \(input.targetLanguageCode)
            proficiency_level_code: \(input.proficiencyLevelCode)
            entry_source: \(input.entrySource.rawValue)
            length_bucket: \(lengthBucket.rawValue)

            source_text:
            \(input.sourceText)
            """
        )
    }

    public static func analyzePrompt(
        input: LearningMaterialAnalysisInput,
        lengthBucket: LearningMaterialEstimatedTokenBucket
    ) -> LearningMaterialRenderedPrompt {
        LearningMaterialRenderedPrompt(
            id: analysisPromptID,
            version: promptVersion,
            system: analysisSystemPrompt,
            user: """
            task: analyze_current_learning_text
            schema_version: \(schemaVersion)
            native_language_code: \(input.nativeLanguageCode)
            target_language_code: \(input.targetLanguageCode)
            proficiency_level_code: \(input.proficiencyLevelCode)
            length_bucket: \(lengthBucket.rawValue)

            learning_text:
            \(input.learningText)
            """
        )
    }
}

private let generationSystemPrompt = """
You generate language-learning material from one user-owned life record.
Return exactly one JSON object. Do not include markdown, code fences, prose outside JSON, API keys, provider metadata, logs, or prompt text.
The object must use schema_version learning_material.v1 and include input_kind, learning_text, revision_notes, and analysis.
input_kind must be nativeRecord, targetWriting, mixed, or uncertain.
learning_text must be in the target learning language. For target-language writing, return a natural revised version and revision_notes.
analysis must be based on learning_text, not the original source text.
"""

private let analysisSystemPrompt = """
You analyze an edited learning text for language practice.
Do not rewrite the learning text. Return exactly one JSON object with schema_version learning_material.v1 and analysis.
Do not include markdown, code fences, prose outside JSON, API keys, provider metadata, logs, or prompt text.
"""
