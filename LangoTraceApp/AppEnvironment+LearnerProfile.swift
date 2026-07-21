import Foundation
import LangoTraceCore
import LangoTraceLearnerModel
import LangoTraceUI

/// Assembles the LM02 Slice 1 learner-profile seam (`LearnerProfileActions`):
/// the compute-on-read snapshot loader plus the system-level Memory governance
/// (explicit-remember add / single soft-delete / system reset). Extracted from
/// `AppEnvironment.swift` to keep that file under the file-length budget. Fully
/// local — no network, no AI.
func makeLearnerProfileActions(
    databaseFactory: SharedAppDatabaseFactory,
    learnerContextProvider: (any LearnerContextProvider)?,
    memoryItemRepository: (any MemoryItemRepository)?
) -> LearnerProfileActions {
    let learnerMemoryRepository: GRDBLearnerMemoryRepository? =
        (try? databaseFactory.database()).map { GRDBLearnerMemoryRepository(writer: $0.writer) }
    // LM02-S3: compute-on-read blind spots from dictation attempts.
    let blindSpotProvider: GRDBLearnerBlindSpotProvider? =
        (try? databaseFactory.database()).map { GRDBLearnerBlindSpotProvider(reader: $0.reader) }
    // LM02-S4b: internal band re-estimation from independent behaviour signals.
    let bandProvider: GRDBLearnerBandProvider? = (try? databaseFactory.database()).map {
        GRDBLearnerBandProvider(
            reader: $0.reader,
            blindSpotProvider: GRDBLearnerBlindSpotProvider(reader: $0.reader)
        )
    }
    return LearnerProfileActions(
        loadSnapshot: { spaceID, languageCode, seedLevel in
            guard let learnerContextProvider, let memoryItemRepository else { return nil }
            let builder = LearnerProfileSnapshotBuilder(
                provider: learnerContextProvider,
                memoryItemRepository: memoryItemRepository,
                blindSpotProvider: blindSpotProvider,
                bandProvider: bandProvider
            )
            return try? await builder.snapshot(
                spaceID: spaceID,
                languageCode: languageCode,
                seedLevel: seedLevel,
                now: Date()
            )
        },
        addFact: { kind, text in
            guard let learnerMemoryRepository else { return }
            try? learnerMemoryRepository.save(
                MemoryFact(id: UUID().uuidString, kind: kind, text: text, createdAt: Date())
            )
        },
        deleteFact: { id in
            guard let learnerMemoryRepository else { return }
            try? learnerMemoryRepository.softDelete(id: id)
        },
        resetAllFacts: {
            guard let learnerMemoryRepository else { return }
            try? learnerMemoryRepository.resetAll()
        }
    )
}
