import Foundation
import LangoTraceCore

/// Dependency injection contract for the photo writing save flow and the
/// explicitly-triggered photo-writing AI assist capability.
///
/// `importPhoto` receives the picker image bytes during save (local primary
/// data — never sent to AI). Returning normally means the attachment was saved.
/// Throwing is fatal to the photo-writing save loop: callers keep the draft on
/// screen and avoid navigating to a no-photo detail.
///
/// The assist seams are separate and only invoked from the explicit
/// "ask AI about this photo" action:
///
/// - `sanitizeImage` is the single boundary that turns raw picker bytes into a
///   `SanitizedAIImage` (downsampled, EXIF/GPS-stripped). The view must route the
///   photo through this before any request and never hand raw bytes to
///   `requestAssist` (privacy floor P1-2).
/// - `requestAssist` sends the sanitized image + non-image input and returns the
///   structured result. App Shell resolves the endpoint/secret and writes the
///   non-sensitive request log; failures map to `PhotoWritingAssistRequestFailure`.
public struct PhotoWritingActions: Sendable {
    public var importPhoto: @Sendable (_ data: Data, _ entryID: String, _ spaceID: String) throws -> Void
    public var sanitizeImage: @Sendable (_ data: Data) async throws -> SanitizedAIImage
    public var requestAssist: @Sendable (
        _ input: PhotoWritingAssistInput,
        _ image: SanitizedAIImage
    ) async throws -> PhotoWritingAssistResult

    public init(
        importPhoto: @escaping @Sendable (Data, String, String) throws -> Void,
        sanitizeImage: @escaping @Sendable (Data) async throws -> SanitizedAIImage = { _ in
            throw PhotoWritingAssistRequestFailure(category: .imageTooLarge)
        },
        requestAssist: @escaping @Sendable (
            PhotoWritingAssistInput,
            SanitizedAIImage
        ) async throws -> PhotoWritingAssistResult = { _, _ in
            throw PhotoWritingAssistRequestFailure(category: .providerNotConfigured)
        }
    ) {
        self.importPhoto = importPhoto
        self.sanitizeImage = sanitizeImage
        self.requestAssist = requestAssist
    }

    /// A no-op placeholder used in previews and test contexts where no real pipeline is wired.
    public static let disabled = PhotoWritingActions(importPhoto: { _, _, _ in })
}
