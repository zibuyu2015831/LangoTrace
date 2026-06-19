import Foundation

/// A table-agnostic sync record (E11). The engine moves these opaque,
/// revision-stamped payloads between a local store and a remote adapter; it
/// never inspects the payload, so the engine is independent of any specific
/// table or of GRDB.
///
/// Privacy: payloads carry only non-sensitive main data (the same snapshots E10
/// exports). Secrets (Keychain) and rebuildable derived data (FTS/vector) are
/// never turned into `SyncRecord`s — that exclusion is enforced by what the
/// local store offers, not by the engine.
public struct SyncRecord: Equatable, Sendable {
    public var id: String
    public var kind: String
    /// Monotonic per-record revision; higher wins ties broken by `updatedAt`.
    public var revision: Int
    public var updatedAt: Date
    public var payload: Data
    public var isDeleted: Bool

    public init(id: String, kind: String, revision: Int, updatedAt: Date, payload: Data, isDeleted: Bool = false) {
        self.id = id
        self.kind = kind
        self.revision = revision
        self.updatedAt = updatedAt
        self.payload = payload
        self.isDeleted = isDeleted
    }
}

/// The remote channel abstraction (核心决策 13: Sync Engine + Adapter, not
/// CloudKit-only). The real iCloud/CloudKit adapter is a separate, deferred
/// slice; `FakeSyncAdapter` backs deterministic engine tests.
public protocol SyncAdapter: Sendable {
    /// Remote records changed since `cursor` (nil = all). Returns the records
    /// plus an opaque cursor to pass next time.
    func fetchChanges(since cursor: String?) async throws -> (records: [SyncRecord], cursor: String)
    /// Pushes local records to the remote channel.
    func push(_ records: [SyncRecord]) async throws
}

/// Resolves a per-id conflict between a local and remote record. v1 policy is
/// last-writer-wins by `(revision, updatedAt)`; a delete tombstone with a higher
/// revision wins over an edit (and vice versa) — deterministic, explainable.
public enum SyncConflictResolver {
    public static func resolve(local: SyncRecord, remote: SyncRecord) -> SyncRecord {
        if remote.revision != local.revision {
            return remote.revision > local.revision ? remote : local
        }
        if remote.updatedAt != local.updatedAt {
            return remote.updatedAt > local.updatedAt ? remote : local
        }
        // Fully tied: prefer the local copy (no spurious churn).
        return local
    }
}

/// Outcome of one synchronize pass.
public struct SyncOutcome: Equatable, Sendable {
    public var converged: [SyncRecord]
    public var appliedFromRemote: Int
    public var pushedToRemote: Int

    public init(converged: [SyncRecord], appliedFromRemote: Int, pushedToRemote: Int) {
        self.converged = converged
        self.appliedFromRemote = appliedFromRemote
        self.pushedToRemote = pushedToRemote
    }
}

/// Pure, local-first sync engine (E11 engine slice). Given the local record set
/// and a remote adapter, it fetches remote changes, resolves per-id conflicts,
/// computes the converged set, and pushes records the remote is missing or
/// behind on. Deterministic and fully testable with a fake adapter — no iCloud
/// dependency. The real CloudKit channel is a deferred slice.
public struct SyncEngine: Sendable {
    public init() {}

    public func synchronize(
        local: [SyncRecord],
        adapter: any SyncAdapter,
        cursor: String? = nil
    ) async throws -> SyncOutcome {
        let remoteFetch = try await adapter.fetchChanges(since: cursor)
        var merged: [String: SyncRecord] = [:]
        for record in local {
            merged[record.id] = record
        }
        var appliedFromRemote = 0
        for remote in remoteFetch.records {
            if let localRecord = merged[remote.id] {
                let winner = SyncConflictResolver.resolve(local: localRecord, remote: remote)
                if winner != localRecord {
                    appliedFromRemote += 1
                }
                merged[remote.id] = winner
            } else {
                merged[remote.id] = remote
                appliedFromRemote += 1
            }
        }
        let converged = merged.values.sorted { $0.id < $1.id }
        // Push records the remote does not have, or has an older revision of.
        let remoteByID = Dictionary(remoteFetch.records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let toPush = converged.filter { record in
            guard let remote = remoteByID[record.id] else { return true }
            return record.revision > remote.revision
                || (record.revision == remote.revision && record.updatedAt > remote.updatedAt)
        }
        if !toPush.isEmpty {
            try await adapter.push(toPush)
        }
        return SyncOutcome(converged: converged, appliedFromRemote: appliedFromRemote, pushedToRemote: toPush.count)
    }
}
