import LangoTraceCore
import SwiftUI

/// Local review-queue seam (E8), injected from App Shell and backed by
/// `GRDBMemoryItemRepository`. Fully local — no external requests.
public struct MemoryReviewActions: Sendable {
    public var loadDueBatch: @Sendable (_ spaceID: String, _ limit: Int) async -> [DepositedMemoryItem]
    public var recordOutcome: @Sendable (_ id: String, _ outcome: MemoryReviewOutcome) async -> Void
    public var markMastered: @Sendable (_ id: String) async -> Void
    public var statistics: @Sendable (_ spaceID: String) async -> MemoryStatistics

    public init(
        loadDueBatch: @escaping @Sendable (String, Int) async -> [DepositedMemoryItem],
        recordOutcome: @escaping @Sendable (String, MemoryReviewOutcome) async -> Void,
        markMastered: @escaping @Sendable (String) async -> Void,
        statistics: @escaping @Sendable (String) async -> MemoryStatistics
    ) {
        self.loadDueBatch = loadDueBatch
        self.recordOutcome = recordOutcome
        self.markMastered = markMastered
        self.statistics = statistics
    }

    public static let disabled = MemoryReviewActions(
        loadDueBatch: { _, _ in [] },
        recordOutcome: { _, _ in },
        markMastered: { _ in },
        statistics: { _ in .zero }
    )
}

public extension EnvironmentValues {
    @Entry var memoryReviewActions = MemoryReviewActions.disabled
}

/// Drives one low-pressure review session: load a small due batch, show each
/// item's target text, reveal its note/example on demand, take a two-option
/// feedback, advance, and summarize. Mid-exit is safe — submitted feedback is
/// already persisted; unreviewed items quietly stay in the queue.
@MainActor
final class MemoryReviewSessionViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case reviewing
        case finished
        case empty
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var batch: [DepositedMemoryItem] = []
    @Published private(set) var index = 0
    @Published private(set) var isRevealed = false
    @Published private(set) var reviewedCount = 0

    private let spaceID: String
    private var actions: MemoryReviewActions
    private let batchLimit: Int

    init(spaceID: String, actions: MemoryReviewActions, batchLimit: Int = 10) {
        self.spaceID = spaceID
        self.actions = actions
        self.batchLimit = batchLimit
    }

    /// Swaps in the environment-injected actions (created with `.disabled`
    /// before the SwiftUI environment is available).
    func reconnect(_ actions: MemoryReviewActions) {
        self.actions = actions
    }

    var currentItem: DepositedMemoryItem? {
        index < batch.count ? batch[index] : nil
    }

    var totalCount: Int {
        batch.count
    }

    func load() async {
        phase = .loading
        batch = await actions.loadDueBatch(spaceID, batchLimit)
        index = 0
        isRevealed = false
        reviewedCount = 0
        phase = batch.isEmpty ? .empty : .reviewing
    }

    func reveal() {
        isRevealed = true
    }

    func submit(_ outcome: MemoryReviewOutcome) async {
        guard let item = currentItem else { return }
        await actions.recordOutcome(item.id, outcome)
        reviewedCount += 1
        advance()
    }

    func masterCurrent() async {
        guard let item = currentItem else { return }
        await actions.markMastered(item.id)
        reviewedCount += 1
        advance()
    }

    private func advance() {
        index += 1
        isRevealed = false
        if index >= batch.count {
            phase = .finished
        }
    }
}
