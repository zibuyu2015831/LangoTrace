import Foundation

/// Failure categories for companion chat vocabulary / expression extraction
/// (LM03-S2a 交付物 A). Lives in Core so the AI engine produces it and the UI
/// store consumes it without the UI depending on the AI package — mirroring
/// `CompanionReplyFailure`.
///
/// An **empty** extraction (the model found no candidates) is *not* a failure: the
/// engine returns `.success([])` and the UI shows "no vocabulary found". A failure
/// here means the request could not be honoured or its output was unusable.
public enum CompanionExtractionError: Error, Equatable, Sendable {
    /// The model's response was not valid structured output — not JSON, or a
    /// candidate is missing a required field (text / kind). Mirrors the
    /// learning-material `.invalidStructuredResponse` branch.
    case invalidStructuredOutput
    /// The provider was unreachable / unsupported / timed out.
    case providerUnavailable
    /// The provider returned a non-success status (auth / model / rate-limit).
    case rejected
    /// The request was cancelled.
    case cancelled
    /// Any other failure; the UI keeps the conversation and reports honestly.
    case other
}
