import Foundation

/// Capabilities that produce an outbound AI text request whose "will-send"
/// preview projection and request log this module models (系列 E6).
///
/// Closed set: extending it requires a deliberate new case plus a projection
/// function in the owning service (see `LangoTraceAI`). The reserved
/// `practiceBacktranslationReview` case has no projection function yet — it is
/// the seam E5 Slice 2 (回译 AI 点评) plugs into without reshaping this contract.
public enum AIRequestCapability: String, Codable, CaseIterable, Equatable, Sendable {
    case learningMaterialGeneration
    case readingSelectionExplanation
    /// Reserved for E5 Slice 2; plugs into the existing
    /// `PracticeMode.backtranslation` practice seam.
    case practiceBacktranslationReview
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
    case nativeLanguageProfile
    case targetLanguageProfile
    case proficiencyLevel
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
