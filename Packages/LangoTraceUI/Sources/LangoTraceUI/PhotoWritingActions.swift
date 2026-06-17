import Foundation

/// Dependency injection contract for the photo writing save flow.
/// The import closure receives the picker image bytes, entry ID, and space ID during save.
/// Returning normally means the attachment was saved. Throwing is fatal to the photo-writing
/// save loop: callers must keep the draft on screen and avoid navigating to a no-photo detail.
public struct PhotoWritingActions: Sendable {
    public var importPhoto: @Sendable (_ data: Data, _ entryID: String, _ spaceID: String) throws -> Void

    public init(importPhoto: @escaping @Sendable (Data, String, String) throws -> Void) {
        self.importPhoto = importPhoto
    }

    /// A no-op placeholder used in previews and test contexts where no real pipeline is wired.
    public static let disabled = PhotoWritingActions(importPhoto: { _, _, _ in })
}
