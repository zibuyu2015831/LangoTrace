import Foundation

public enum ReadingAsyncState: Equatable, Sendable {
    case idle
    case loading
    case failed
}

public enum ReadingDocumentSaveFailure: Equatable, Sendable {
    case emptyBody
    case generic

    public var messageKey: String {
        switch self {
        case .emptyBody:
            "reading.editor.error.emptyBody"
        case .generic:
            "reading.editor.error.generic"
        }
    }
}
