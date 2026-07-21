import Foundation

/// Pure selection layer for companion Memory injection (LM03-S2b-1).
///
/// v1 ranking = **recency + kind quota** (user decision 2026-06-25): most-recent
/// first, but round-robin across `MemoryFactKind` so a single chatty kind cannot
/// monopolise the small budget. The `salience` column is deliberately **not**
/// consulted in v1 (reserved for a v2 FTS relevance recall).
///
/// Pure function of `[MemoryFact]` → `[MemoryFact]`; it stays on the user's life
/// context only and carries none of the proficiency-estimate machinery (ADR-006
/// red line — Memory facts are unrelated to the proficiency signal). It also
/// re-sorts internally and does **not** trust the provider's return order
/// (`memoryFacts` is oldest-first), and defensively keeps only `.global` facts
/// (no `companionOnly` writer exists in v1).
public enum CompanionMemorySelection {
    public static func select(facts: [MemoryFact], limit: Int = 5) -> [MemoryFact] {
        guard limit > 0 else { return [] }

        // Active, global-visibility only; newest first (tie-break on id for
        // determinism), independent of the input order.
        let ranked = facts
            .filter { $0.softDeletedAt == nil && $0.visibility == .global }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id > rhs.id
            }

        // Bucket by kind preserving the recency order within each kind.
        var buckets: [MemoryFactKind: [MemoryFact]] = [:]
        for fact in ranked {
            buckets[fact.kind, default: []].append(fact)
        }

        // Round-robin: each round takes the head of every non-empty kind, visiting
        // kinds in the recency order of their heads. A kind only gets a second pick
        // once every other kind has contributed one (diversity quota).
        var result: [MemoryFact] = []
        while result.count < limit {
            let heads = MemoryFactKind.allCases
                .compactMap { buckets[$0]?.first }
                .sorted { lhs, rhs in
                    if lhs.createdAt != rhs.createdAt {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return lhs.id > rhs.id
                }
            if heads.isEmpty {
                break
            }
            for head in heads where result.count < limit {
                buckets[head.kind]?.removeFirst()
                result.append(head)
            }
        }
        return result
    }
}
