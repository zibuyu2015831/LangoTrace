import Foundation
import LangoTraceCore

/// Typed marker for a directive in the companion summarization prompt (LM03-S3b-1).
/// Structured so the privacy boundary is structurally verifiable, not brittle
/// against wording — mirrors `CompanionPromptDirective` / `CompanionExtractionDirective`.
public enum CompanionSummarizationDirective: Equatable, Hashable, Sendable {
    /// Summarize only what appears in the supplied conversation turns; never invent
    /// or add anything not said (AI-17 + privacy boundary).
    case groundedInConversationNoFabrication
    /// Produce a brief third-person recap of what was discussed (so the companion
    /// stays grounded in "what we talked about earlier").
    case thirdPersonRecap
    /// Do not profile the learner and do not pull in any external data — only this
    /// conversation's own turns are in scope.
    case noProfilingNoExternalData
    /// Fold the prior summary (if any) into the new one rather than restating it.
    case foldPriorSummary
}

/// A rendered companion summarization prompt: the assembled text plus the typed
/// directive set.
public struct CompanionSummarizationRenderedPrompt: Equatable, Sendable {
    public var id: String
    public var version: String
    public var text: String
    public var directives: Set<CompanionSummarizationDirective>

    public init(
        id: String,
        version: String,
        text: String,
        directives: Set<CompanionSummarizationDirective>
    ) {
        self.id = id
        self.version = version
        self.text = text
        self.directives = directives
    }
}

/// Builds the companion conversation-summarization system prompt (LM03-S3b-1 "对话
/// 记忆"). Pure function — the conversation turns and the prior summary are supplied
/// as separate reference messages, never concatenated into the instruction region
/// (AI-17). The summary it produces compresses *this conversation's own turns* only;
/// it must not profile the learner or fold in any external data.
public enum CompanionSummarizationPromptRegistry {
    public static let summarizationPromptID = "builtin.companion.summary.v1"
    public static let promptVersion = "1"

    public static func summarizationPrompt(
        targetLanguageCode: String,
        nativeLanguageCode: String?
    ) -> CompanionSummarizationRenderedPrompt {
        let directives: Set<CompanionSummarizationDirective> = [
            .groundedInConversationNoFabrication,
            .thirdPersonRecap,
            .noProfilingNoExternalData,
            .foldPriorSummary,
        ]
        let native = nativeLanguageCode ?? "the learner's native language"
        let lines = [
            "You compress the earlier part of a language-practice conversation between "
                + "a learner (target language \(targetLanguageCode), native language "
                + "\(native)) and their companion into a brief running summary, so the "
                + "companion can stay grounded in what was discussed without re-reading "
                + "every turn.",
            "Write a concise third-person recap of what was talked about: topics, things "
                + "the learner mentioned, and where the conversation left off.",
            "Summarize ONLY what actually appears in the conversation turns provided "
                + "below. Do not invent details, do not add facts, and do not profile the "
                + "learner — you are recapping this conversation, nothing else.",
            "If a prior summary is provided, fold it into a single updated summary rather "
                + "than repeating it separately.",
            "Respond with ONLY the summary text — no preamble, no list markers, no JSON.",
        ]
        return CompanionSummarizationRenderedPrompt(
            id: summarizationPromptID,
            version: promptVersion,
            text: lines.joined(separator: "\n\n"),
            directives: directives
        )
    }
}
