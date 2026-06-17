import Foundation

/// Dependency injection contract for the photo writing save flow.
/// The import closure receives the picker image bytes, entry ID, and space ID after the entry is
/// created; returning normally means the attachment was saved. Throwing is non-fatal — the entry
/// has already been created and navigation to the detail view proceeds.
public struct PhotoWritingActions: Sendable {
    public var importPhoto: @Sendable (_ data: Data, _ entryID: String, _ spaceID: String) throws -> Void

    public init(importPhoto: @escaping @Sendable (Data, String, String) throws -> Void) {
        self.importPhoto = importPhoto
    }

    /// A no-op placeholder used in previews and test contexts where no real pipeline is wired.
    public static let disabled = PhotoWritingActions(importPhoto: { _, _, _ in })
}
