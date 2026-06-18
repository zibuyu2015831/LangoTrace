import Foundation
@testable import LangoTraceSync
import Testing

/// Covers the E11 sync engine slice: conflict resolution, remote merge, push of
/// missing/newer records, and two-engine convergence over a shared fake remote.
/// Fully deterministic — no iCloud (the real CloudKit channel is deferred).
@Suite("Sync engine")
struct SyncEngineTests {
    private func record(
        _ id: String,
        revision: Int,
        at seconds: TimeInterval,
        deleted: Bool = false,
        body: String = "x"
    ) -> SyncRecord {
        SyncRecord(
            id: id, kind: "entry", revision: revision,
            updatedAt: Date(timeIntervalSince1970: seconds),
            payload: Data(body.utf8), isDeleted: deleted
        )
    }

    @Test("conflict resolution is last-writer-wins by revision then timestamp")
    func conflictResolution() {
        let local = record("a", revision: 1, at: 100)
        let higherRevisionRemote = record("a", revision: 2, at: 50)
        #expect(SyncConflictResolver.resolve(local: local, remote: higherRevisionRemote) == higherRevisionRemote)

        let newerLocal = record("a", revision: 2, at: 200)
        let olderRemote = record("a", revision: 2, at: 100)
        #expect(SyncConflictResolver.resolve(local: newerLocal, remote: olderRemote) == newerLocal)
    }

    @Test("synchronize merges remote-only records and pushes local-only records")
    func mergeAndPush() async throws {
        let remote = FakeSyncAdapter(records: [record("r1", revision: 1, at: 10)])
        let engine = SyncEngine()
        let outcome = try await engine.synchronize(local: [record("l1", revision: 1, at: 20)], adapter: remote)
        #expect(outcome.converged.map(\.id) == ["l1", "r1"])
        #expect(outcome.appliedFromRemote == 1)
        #expect(outcome.pushedToRemote == 1) // l1 pushed
        #expect(await remote.pushedIDs.contains("l1"))
    }

    @Test("a higher-revision remote edit overwrites the local record")
    func remoteWins() async throws {
        let remote = FakeSyncAdapter(records: [record("a", revision: 3, at: 5, body: "remote")])
        let engine = SyncEngine()
        let local = [record("a", revision: 1, at: 99, body: "local")]
        let outcome = try await engine.synchronize(local: local, adapter: remote)
        let merged = outcome.converged.first { $0.id == "a" }
        #expect(merged?.revision == 3)
        #expect(merged.map { String(bytes: $0.payload, encoding: .utf8) ?? "" } == "remote")
    }

    @Test("two engines over a shared remote converge to the same record set")
    func twoEnginesConverge() async throws {
        let remote = SharedFakeRemote()
        let engine = SyncEngine()
        _ = try await engine.synchronize(local: [record("a", revision: 1, at: 10)], adapter: remote)
        let second = try await engine.synchronize(local: [record("b", revision: 1, at: 20)], adapter: remote)
        // Second device now sees both a and b.
        #expect(second.converged.map(\.id) == ["a", "b"])
    }

    @Test("a delete tombstone with a higher revision wins over a local edit")
    func tombstonePropagates() async throws {
        let remote = FakeSyncAdapter(records: [record("a", revision: 2, at: 5, deleted: true)])
        let engine = SyncEngine()
        let outcome = try await engine.synchronize(local: [record("a", revision: 1, at: 99)], adapter: remote)
        #expect(outcome.converged.first { $0.id == "a" }?.isDeleted == true)
    }
}

/// In-memory fake remote that records pushes (single fetch view).
private actor FakeSyncAdapter: SyncAdapter {
    private var records: [SyncRecord]
    private(set) var pushedIDs: Set<String> = []

    init(records: [SyncRecord]) {
        self.records = records
    }

    func fetchChanges(since _: String?) async throws -> (records: [SyncRecord], cursor: String) {
        (records, "cursor")
    }

    func push(_ pushed: [SyncRecord]) async throws {
        for record in pushed {
            pushedIDs.insert(record.id)
        }
    }
}

/// Fake remote that accumulates pushes so a second sync sees them (convergence).
private actor SharedFakeRemote: SyncAdapter {
    private var store: [String: SyncRecord] = [:]

    func fetchChanges(since _: String?) async throws -> (records: [SyncRecord], cursor: String) {
        (store.values.sorted { $0.id < $1.id }, "cursor")
    }

    func push(_ pushed: [SyncRecord]) async throws {
        for record in pushed {
            store[record.id] = record
        }
    }
}
