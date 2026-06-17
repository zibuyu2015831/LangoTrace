import Foundation
import LangoTraceCore
import LangoTraceData

enum PhotoWritingSaveError: Error, Equatable {
    case photoRequired
    case photoImportFailed
}

struct PhotoWritingSaveCoordinator {
    var createEntry: (_ title: String, _ body: String, _ source: EntrySource) throws -> LearningEntry
    var deleteEntry: (_ entryID: String) throws -> Void
    var importPhoto: (_ data: Data, _ entryID: String, _ spaceID: String) throws -> Void

    @discardableResult
    func save(body: String, imageData: Data?, spaceID: String) throws -> LearningEntry {
        guard let imageData else {
            throw PhotoWritingSaveError.photoRequired
        }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = String(trimmedBody.prefix(80))
        let entry = try createEntry(title, trimmedBody, .photoWriting)

        do {
            try importPhoto(imageData, entry.id, spaceID)
        } catch {
            try? deleteEntry(entry.id)
            throw PhotoWritingSaveError.photoImportFailed
        }

        return entry
    }
}
