public enum ReadingDocumentLifecycleEventType: String, Equatable, Hashable, Sendable {
    case imported
    case opened
    case updated
    case softDeleted
    case restored
    case assignedCollection
    case removedCollection
    case tagged
    case untagged
}
