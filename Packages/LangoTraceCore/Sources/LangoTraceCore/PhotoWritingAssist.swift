import Foundation

/// The two output modes of the photo-writing AI assist capability. One prompt id
/// serves both; the mode selects the rendered instructions and the matching
/// strict response schema (see `LangoTraceAI` `PhotoWritingAssistService`).
public enum PhotoWritingAssistMode: String, Codable, CaseIterable, Equatable, Sendable {
    /// 写作提示：scene summary + writing angles + useful expressions + guiding
    /// questions, so the learner writes the target-language text themselves.
    case writingSuggestions
    /// 母语草稿：a short native-language draft the learner then translates into
    /// the target language (看图 → 母语表达 → 翻译成目标语).
    case sourceLanguageDraft
}

/// Non-image inputs for a photo-writing assist request. The photo itself travels
/// separately as a `SanitizedAIImage` so the service can never receive raw
/// camera-roll bytes (privacy floor P1-2).
public struct PhotoWritingAssistInput: Equatable, Sendable {
    public var mode: PhotoWritingAssistMode
    /// Optional note the user typed in the writing area; may be empty.
    public var userNote: String
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var proficiencyLevelCode: String

    public init(
        mode: PhotoWritingAssistMode,
        userNote: String,
        nativeLanguageCode: String,
        targetLanguageCode: String,
        proficiencyLevelCode: String
    ) {
        self.mode = mode
        self.userNote = userNote
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
    }
}

/// A privacy-sanitized image ready to send to an AI provider: EXIF/GPS stripped,
/// downsampled to a controlled edge, re-encoded, base64-encoded. The *only* image
/// shape the AI request boundary accepts — there is no path that hands raw
/// `PhotosPicker`/camera-roll `Data` to a request (P1-1 / P1-2).
public struct SanitizedAIImage: Equatable, Sendable {
    public var base64: String
    /// e.g. `image/jpeg`.
    public var mimeType: String
    /// Encoded byte count of the underlying image data (pre-base64), used to
    /// enforce the request byte cap.
    public var byteCount: Int

    public init(base64: String, mimeType: String, byteCount: Int) {
        self.base64 = base64
        self.mimeType = mimeType
        self.byteCount = byteCount
    }

    /// `data:` URL form embedded in the request body.
    public var dataURL: String {
        "data:\(mimeType);base64,\(base64)"
    }
}

/// A target-language expression paired with its native-language gloss.
public struct PhotoWritingAssistExpression: Equatable, Sendable {
    public var targetText: String
    public var nativeGloss: String

    public init(targetText: String, nativeGloss: String) {
        self.targetText = targetText
        self.nativeGloss = nativeGloss
    }
}

/// The structured result of a photo-writing assist request. The payload is
/// mode-specific (P2-3: each mode maps to its own strict schema).
public struct PhotoWritingAssistResult: Equatable, Sendable {
    public var schemaVersion: String
    public var mode: PhotoWritingAssistMode
    public var payload: Payload

    public init(schemaVersion: String, mode: PhotoWritingAssistMode, payload: Payload) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.payload = payload
    }

    public enum Payload: Equatable, Sendable {
        case writingSuggestions(WritingSuggestions)
        case sourceLanguageDraft(SourceLanguageDraft)
    }

    public struct WritingSuggestions: Equatable, Sendable {
        /// A brief native-language description of what the photo shows.
        public var sceneSummary: String
        /// Native-language angles the learner could write about.
        public var writingAngles: [String]
        /// Target-language phrases with native glosses the learner can reuse.
        public var usefulExpressions: [PhotoWritingAssistExpression]
        /// Native-language guiding questions.
        public var guidingQuestions: [String]

        public init(
            sceneSummary: String,
            writingAngles: [String],
            usefulExpressions: [PhotoWritingAssistExpression],
            guidingQuestions: [String]
        ) {
            self.sceneSummary = sceneSummary
            self.writingAngles = writingAngles
            self.usefulExpressions = usefulExpressions
            self.guidingQuestions = guidingQuestions
        }
    }

    public struct SourceLanguageDraft: Equatable, Sendable {
        /// A short native-language draft the learner will translate.
        public var draft: String
        /// Optional target-language vocabulary hints to aid the translation.
        public var keyVocabularyHints: [PhotoWritingAssistExpression]

        public init(draft: String, keyVocabularyHints: [PhotoWritingAssistExpression]) {
            self.draft = draft
            self.keyVocabularyHints = keyVocabularyHints
        }
    }
}

/// Closed failure taxonomy for the photo-writing assist service, mirroring the
/// other AI text services. `imageInputNotEnabled` is photo-specific: it means the
/// endpoint can take images but the user has not enabled image input yet, so the
/// UI routes to a guidance state rather than a hard error.
public enum PhotoWritingAssistFailureCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case providerNotConfigured
    case imageInputNotEnabled
    case unsupportedProvider
    case authenticationFailed
    case networkUnavailable
    case timeout
    case rateLimited
    case providerRejected
    case unsupportedModel
    case invalidStructuredResponse
    case imageTooLarge
    case cancelled
}
