import Foundation

/// Navigation seed for the Language Companion chat. `sourceEntryID` is non-nil
/// when launched from a record's "talk about this record" entry (plan-A); nil for
/// the general practice-tab entry (cold-start greeting, zero outbound).
public struct CompanionChatRouteSeed: Hashable, Sendable {
    public var sourceEntryID: String?

    public init(sourceEntryID: String? = nil) {
        self.sourceEntryID = sourceEntryID
    }
}
