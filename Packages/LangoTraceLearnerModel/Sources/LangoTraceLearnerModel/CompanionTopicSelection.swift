import Foundation
import LangoTraceCore

/// Pure selection layer for companion 方案B topic finding (LM03-S2b-2).
///
/// v1 = **recency only** (user decision 2026-06-26: minimal interaction, "smart"
/// feel): pick the most recent candidate as the topic seed, minimal send (top-1).
/// FTS relevance ranking is deferred (the FTS index needs an explicit rebuild and
/// its folded body mixes in AI text — see plan). The `salience`-style weighting is
/// not consulted.
///
/// Pure function of `[CompanionTopicCandidate]` → `[CompanionTopicCandidate]`; it
/// stays on the user's own record text only and carries none of the
/// proficiency-estimate machinery (ADR-006 red line — topic candidates are the
/// user's records, unrelated to the proficiency signal). It re-sorts internally
/// and does not trust the caller's order.
public enum CompanionTopicSelection {
    public static func select(
        candidates: [CompanionTopicCandidate],
        limit: Int = 1
    ) -> [CompanionTopicCandidate] {
        guard limit > 0 else { return [] }
        let ranked = candidates.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id > rhs.id
        }
        return Array(ranked.prefix(limit))
    }
}
