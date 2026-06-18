import Foundation

/// A learner's feedback on a reviewed memory item (E8). Two low-pressure
/// options — no scoring, no grading.
public enum MemoryReviewOutcome: String, Codable, CaseIterable, Equatable, Sendable {
    case remembered
    case needsAnotherLook
}

/// The scheduling result for one memory item: its review state, rung on the
/// interval ladder, next due date, and (when reached) mastery timestamp.
public struct MemoryReviewSchedule: Equatable, Sendable {
    public var state: MemoryReviewState
    public var rung: Int
    public var dueAt: Date?
    public var masteredAt: Date?

    public init(state: MemoryReviewState, rung: Int, dueAt: Date?, masteredAt: Date?) {
        self.state = state
        self.rung = rung
        self.dueAt = dueAt
        self.masteredAt = masteredAt
    }
}

/// Pure, local, fixed-interval review scheduler (E8). No external requests, no
/// vectors — just a deterministic interval ladder over the `memory_items`
/// review columns. Injecting `now` keeps it fully testable.
public enum MemoryReviewScheduler {
    /// Days until the next review at each ladder rung. Remembering at the top
    /// rung graduates the item to `mastered`.
    public static let rungIntervalDays = [1, 3, 7, 14, 30]

    /// Computes the next schedule from the current state + the learner's
    /// feedback. `remembered` advances the ladder (or masters at the top);
    /// `needsAnotherLook` resets to the first rung (due tomorrow).
    public static func schedule(
        state: MemoryReviewState,
        rung: Int,
        outcome: MemoryReviewOutcome,
        now: Date
    ) -> MemoryReviewSchedule {
        switch outcome {
        case .needsAnotherLook:
            return MemoryReviewSchedule(
                state: .scheduled,
                rung: 0,
                dueAt: due(afterDays: rungIntervalDays[0], from: now),
                masteredAt: nil
            )
        case .remembered:
            let nextRung = state == .new ? 0 : rung + 1
            if nextRung >= rungIntervalDays.count {
                return MemoryReviewSchedule(state: .mastered, rung: rung, dueAt: nil, masteredAt: now)
            }
            return MemoryReviewSchedule(
                state: .scheduled,
                rung: nextRung,
                dueAt: due(afterDays: rungIntervalDays[nextRung], from: now),
                masteredAt: nil
            )
        }
    }

    /// Manually marks an item mastered (skips the ladder).
    public static func markMastered(now: Date) -> MemoryReviewSchedule {
        MemoryReviewSchedule(state: .mastered, rung: 0, dueAt: nil, masteredAt: now)
    }

    /// Resumes review for a mastered item — back to the first rung, due tomorrow.
    public static func resumeReview(now: Date) -> MemoryReviewSchedule {
        MemoryReviewSchedule(
            state: .scheduled,
            rung: 0,
            dueAt: due(afterDays: rungIntervalDays[0], from: now),
            masteredAt: nil
        )
    }

    private static func due(afterDays days: Int, from now: Date) -> Date {
        now.addingTimeInterval(TimeInterval(days) * 86400)
    }
}

/// Low-pressure memory dashboard counts (E8). Computed from local data only.
public struct MemoryStatistics: Equatable, Sendable {
    public var depositedThisWeek: Int
    public var dueCount: Int
    public var masteredCount: Int

    public init(depositedThisWeek: Int, dueCount: Int, masteredCount: Int) {
        self.depositedThisWeek = depositedThisWeek
        self.dueCount = dueCount
        self.masteredCount = masteredCount
    }

    public static let zero = MemoryStatistics(depositedThisWeek: 0, dueCount: 0, masteredCount: 0)
}
