import LangoTraceLearnerModel
import SwiftUI

/// Local learner-profile seam (LM02 Slice 1), injected from App Shell and backed
/// by `GRDBLearnerContextProvider` + `GRDBLearnerMemoryRepository` +
/// `LearnerProfileSnapshotBuilder`. Fully local — no external requests, no AI.
public struct LearnerProfileActions: Sendable {
    /// Builds the compute-on-read snapshot for the active space + language.
    /// Returns `nil` when the App has no database (e.g. recovery state).
    public var loadSnapshot: @Sendable (_ spaceID: String, _ languageCode: String) async -> LearnerProfileSnapshot?
    /// Explicitly saves a Memory fact (the user actively remembers something). No
    /// auto-extraction.
    public var addFact: @Sendable (_ kind: MemoryFactKind, _ text: String) async -> Void
    /// Soft-deletes a single Memory fact (recoverable, §12.3).
    public var deleteFact: @Sendable (_ id: String) async -> Void
    /// System-level "reset what the App knows about me" — physically deletes all
    /// Memory facts (§12.3). Does NOT touch `memory_items` / learning records.
    public var resetAllFacts: @Sendable () async -> Void

    public init(
        loadSnapshot: @escaping @Sendable (String, String) async -> LearnerProfileSnapshot?,
        addFact: @escaping @Sendable (MemoryFactKind, String) async -> Void,
        deleteFact: @escaping @Sendable (String) async -> Void,
        resetAllFacts: @escaping @Sendable () async -> Void
    ) {
        self.loadSnapshot = loadSnapshot
        self.addFact = addFact
        self.deleteFact = deleteFact
        self.resetAllFacts = resetAllFacts
    }

    public static let disabled = LearnerProfileActions(
        loadSnapshot: { _, _ in nil },
        addFact: { _, _ in },
        deleteFact: { _ in },
        resetAllFacts: {}
    )
}

public extension EnvironmentValues {
    @Entry var learnerProfileActions = LearnerProfileActions.disabled
}
