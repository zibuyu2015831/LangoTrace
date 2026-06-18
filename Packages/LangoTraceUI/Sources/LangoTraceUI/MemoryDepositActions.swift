import LangoTraceCore
import SwiftUI

/// Explicit "add to memory" deposit seam (E7), injected from App Shell and
/// backed by `GRDBMemoryItemRepository`. The UI only knows a candidate id; the
/// App Shell resolves the full candidate and deposits idempotently. Local-only.
public struct MemoryDepositActions: Sendable {
    public var depositCandidate: @Sendable (_ candidateID: String, _ spaceID: String) async -> Bool
    public var listDeposited: @Sendable (_ spaceID: String) async -> [DepositedMemoryItem]
    public var depositedCandidateIDs: @Sendable (_ spaceID: String) async -> Set<String>
    /// Entry ids with at least one deposited memory item (drives the `settled`
    /// timeline filter).
    public var depositedEntryIDs: @Sendable (_ spaceID: String) async -> Set<String>

    public init(
        depositCandidate: @escaping @Sendable (String, String) async -> Bool,
        listDeposited: @escaping @Sendable (String) async -> [DepositedMemoryItem],
        depositedCandidateIDs: @escaping @Sendable (String) async -> Set<String>,
        depositedEntryIDs: @escaping @Sendable (String) async -> Set<String> = { _ in [] }
    ) {
        self.depositCandidate = depositCandidate
        self.listDeposited = listDeposited
        self.depositedCandidateIDs = depositedCandidateIDs
        self.depositedEntryIDs = depositedEntryIDs
    }

    public static let disabled = MemoryDepositActions(
        depositCandidate: { _, _ in false },
        listDeposited: { _ in [] },
        depositedCandidateIDs: { _ in [] },
        depositedEntryIDs: { _ in [] }
    )
}

public extension EnvironmentValues {
    @Entry var memoryDepositActions = MemoryDepositActions.disabled
}
