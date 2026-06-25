import Foundation
import LangoTraceCore
import LangoTraceUI

/// Assembles the E8 local memory-review-queue actions over the E7 `memory_items`
/// columns. Extracted from `AppEnvironment.swift` to keep that file under the
/// file-length budget. Fully local — no network, no AI.
func makeMemoryReviewActions(memoryItemRepository: (any MemoryItemRepository)?) -> MemoryReviewActions {
    MemoryReviewActions(
        loadDueBatch: { spaceID, limit in
            guard let memoryItemRepository else { return [] }
            return await (try? memoryItemRepository.dueItems(spaceID: spaceID, limit: limit, now: Date())) ?? []
        },
        recordOutcome: { id, outcome in
            guard let memoryItemRepository else { return }
            _ = try? await memoryItemRepository.recordReviewOutcome(id: id, outcome: outcome, now: Date())
        },
        markMastered: { id in
            guard let memoryItemRepository else { return }
            try? await memoryItemRepository.markMastered(id: id, now: Date())
        },
        statistics: { spaceID in
            guard let memoryItemRepository else { return .zero }
            return await (try? memoryItemRepository.memoryStatistics(spaceID: spaceID, now: Date())) ?? .zero
        }
    )
}
