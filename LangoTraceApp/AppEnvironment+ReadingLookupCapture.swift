import Foundation
import LangoTraceCore
import LangoTraceData
import LangoTraceLearnerModel
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

/// Assembles the LM02-S4b band-level source for derive(): re-estimates the internal
/// band from independent behaviour signals (S4a lookups + S3 errors) and returns
/// its level. Pure local — never outbound, never reads AI difficulty.
func makeReadingBandLevelSource(
    databaseFactory: SharedAppDatabaseFactory
) -> ReadingBandLevelSource {
    let provider: GRDBLearnerBandProvider? = (try? databaseFactory.database()).map {
        GRDBLearnerBandProvider(
            reader: $0.reader,
            blindSpotProvider: GRDBLearnerBlindSpotProvider(reader: $0.reader)
        )
    }
    return { languageCode, seedLevel in
        guard let provider else { return nil }
        return (try? provider.band(languageCode: languageCode, seedLevel: seedLevel))?.estimatedLevel
    }
}
