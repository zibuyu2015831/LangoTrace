import Foundation

/// Capabilities that produce an outbound AI text request whose "will-send"
/// preview projection and request log this module models (系列 E6).
///
/// Closed set: extending it requires a deliberate new case plus a projection
/// function in the owning service (see `LangoTraceAI`). Every case below has a
/// live projection function.
public enum AIRequestCapability: String, Codable, CaseIterable, Equatable, Sendable {
    case learningMaterialGeneration
    case readingSelectionExplanation
    /// Back-translation critique; plugs into the existing
    /// `PracticeMode.backtranslation` practice seam.
    case practiceBacktranslationReview
    /// Photo-writing AI assist (看图辅助写作). The *only* capability whose
    /// projection includes `photoAttachments`: a photo enters an outbound AI
    /// request solely through this explicit, user-triggered action. All other
    /// capabilities keep excluding photos (see `LangoTraceAI`
    /// `alwaysExcludedContent`).
    case photoWritingAssist
    /// Companion chat vocabulary / expression extraction (LM03-S2a). Sends the
    /// *conversation the user already shared turn-by-turn* back to the same
    /// provider, on an explicit "extract" action, to mine review candidates — the
    /// same shape as 生成学习材料 / 重新分析 (re-send already-stored user content on
    /// an explicit trigger). It introduces **no new outbound content category**:
    /// its only included descriptor is `companionConversation`. NOT a system
    /// auto-injection (decision #10) — that gated path is Memory injection (S2b).
    case companionExtraction
    /// Companion conversation send (LM03-S1 + S2b-1). The first capability that
    /// models the *outbound conversation request itself*. When the user has
    /// consented to Memory injection (and the per-conversation toggle is on), its
    /// projection additionally discloses `.curatedLearnerMemory` — the **only**
    /// path on which a curated, scrubbed subset of long-term memory egresses
    /// (decision #10 system auto-injection, behind the one-time preview gate).
    /// Preview-only in S2b-1: it does not write `ai_request_logs` (conversation-
    /// level logging is deferred).
    case companionConversation
}

/// Closed vocabulary describing *categories* of content a request includes or
/// explicitly excludes.
///
/// Deliberately NOT free text: the preview must never become a surface that
/// leaks the actual content being sent (`docs/spec/005` §4.7). A descriptor
/// names a class of data ("the current entry body"), never the data itself.
public enum AIRequestContentDescriptor: String, Codable, CaseIterable, Equatable, Sendable {
    // Included categories.
    case currentEntryBody
    case currentLearningText
    case selectedReadingPassage
    case readingContextWindow
    case practiceAttempt
    case backtranslationReferenceSentence
    /// The companion conversation the user already shared turn-by-turn, re-sent on
    /// an explicit "extract" action (LM03-S2a). Names the conversation as a
    /// category — never the message bodies.
    case companionConversation
    case nativeLanguageProfile
    case targetLanguageProfile
    case proficiencyLevel
    /// The curated, scrubbed top-5 subset of long-term memory life facts that the
    /// companion request injects after the user's one-time consent (LM03-S2b-1).
    /// Deliberately distinct from `.longTermMemory`: the raw long-term memory
    /// store stays globally excluded (never bulk-sent), while this names the
    /// derived, consented subset that *is* sent — so the preview can honestly show
    /// both "sends: curated subset" and "does not send: full memory store".
    case curatedLearnerMemory
    /// One of the user's own saved records, brought into the conversation as a
    /// topic — either explicitly by the user (方案A "talk about this record") or,
    /// after one-time consent, auto-selected by the companion to find a topic
    /// (方案B, LM03-S2b-2). Shared by both paths so the preview honestly discloses
    /// that a record body is sent. Names the record as a category, never its body.
    case broughtInRecords
    // Always-excluded categories (the privacy guarantees the preview asserts).
    case historicalEntries
    case photoAttachments
    case audioRecordings
    case longTermMemory
    case apiCredential
    case otherLanguageSpaces
}

/// Coarse, non-identifying size bucket for an outbound request. Never the exact
/// length — a bucket cannot be reversed into the content.
public enum AIRequestLengthBucket: String, Codable, CaseIterable, Equatable, Sendable {
    case short
    case medium
    case long

    /// Maps the learning-material estimated-token bucket onto the shared scale.
    public init(_ bucket: LearningMaterialEstimatedTokenBucket) {
        switch bucket {
        case .short: self = .short
        case .medium: self = .medium
        case .tooLong: self = .long
        }
    }

    /// Coarse bucket from a character count (reading selection has no token
    /// bucket of its own).
    public init(characterCount: Int) {
        switch characterCount {
        case ..<400: self = .short
        case 400 ..< 1600: self = .medium
        default: self = .long
        }
    }
}

/// The real "将发送内容" projection shared by every AI text capability.
///
/// Constructed from the *same* input that builds the actual request (the owning
/// service exposes a pure `previewProjection(for:)` function), so the preview
/// cannot drift from what is sent. It carries only non-sensitive descriptors —
/// provider preset, model, prompt id/version, a size bucket, and the
/// included/excluded content *categories* — never any rendered prompt body or
/// user content.
public struct AIRequestPreviewProjection: Equatable, Sendable {
    public var capability: AIRequestCapability
    public var providerPresetID: String?
    public var modelName: String?
    public var promptID: String?
    public var promptVersion: String?
    public var lengthBucket: AIRequestLengthBucket
    public var includedContent: [AIRequestContentDescriptor]
    public var excludedContent: [AIRequestContentDescriptor]

    public init(
        capability: AIRequestCapability,
        providerPresetID: String?,
        modelName: String?,
        promptID: String?,
        promptVersion: String?,
        lengthBucket: AIRequestLengthBucket,
        includedContent: [AIRequestContentDescriptor],
        excludedContent: [AIRequestContentDescriptor]
    ) {
        self.capability = capability
        self.providerPresetID = providerPresetID
        self.modelName = modelName
        self.promptID = promptID
        self.promptVersion = promptVersion
        self.lengthBucket = lengthBucket
        self.includedContent = includedContent
        self.excludedContent = excludedContent
    }
}
