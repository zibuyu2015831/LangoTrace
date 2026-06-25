import Foundation
import LangoTraceCore
import LangoTraceData
import LangoTraceUI

/// Assembles the LM02-S4a reading lookup-capture action: when the user requests
/// an explanation, persist a `DictionaryLookupEvent` (a behaviour signal for S4b
/// band re-estimation). Pure local — never outbound, never records AI content.
func makeReadingLookupCaptureAction(
    databaseFactory: SharedAppDatabaseFactory
) -> ReadingLookupCaptureAction {
    let repository: GRDBDictionaryLookupEventRepository? =
        (try? databaseFactory.database()).map { GRDBDictionaryLookupEventRepository(writer: $0.writer) }
    return { input in
        guard let repository else { return }
        try? repository.record(DictionaryLookupEvent(
            id: UUID().uuidString,
            languageSpaceID: input.spaceID,
            lookedUpTerm: input.lookedUpTerm,
            sourceContentID: input.documentID,
            occurredAt: Date()
        ))
    }
}
