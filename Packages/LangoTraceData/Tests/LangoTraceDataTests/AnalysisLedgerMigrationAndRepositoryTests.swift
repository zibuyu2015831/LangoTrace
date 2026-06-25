import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// Covers LM02-S4a: the v28 dictionary-lookup-event table + v29 analysis-ledger
/// migration (structural), the lookup-event repository (record / windowed read /
/// local-only policy / source-origin forward seam), and the ledger high-water
/// cursor (incremental skip / version-bump re-run / monotonic advance).
@Suite("Analysis ledger migration and repositories")
struct AnalysisLedgerMigrationAndRepositoryTests {
    private func makeDatabase() throws -> (AppDatabase, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        return (database, queue)
    }

    private func seedSpace(_ db: Database, id: String = "s1") throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at)
            VALUES (?, 'zh-Hans', 'en', 'b1', ?, ?, 0, 0)
            """,
            arguments: [id, id, id]
        )
    }

    private func event(_ id: String, term: String, at: Double, space: String = "s1") -> DictionaryLookupEvent {
        DictionaryLookupEvent(
            id: id, languageSpaceID: space, lookedUpTerm: term,
            sourceContentID: "doc-1", occurredAt: Date(timeIntervalSince1970: at)
        )
    }

    // MARK: - Migration structure

    @Test("v28/v29 create the lookup-event and analysis-ledger tables")
    func migrationCreatesLookupEventAndLedgerTables() throws {
        let (_, queue) = try makeDatabase()
        try queue.read { db in
            #expect(try db.tableExists("dictionary_lookup_events"))
            #expect(try db.tableExists("analysis_ledger"))
            let lookupColumns = try db.columns(in: "dictionary_lookup_events").map(\.name)
            for expected in [
                "id", "language_space_id", "looked_up_term", "source_content_id",
                "source_content_origin", "sync_policy", "backup_policy", "export_policy",
                "occurred_at", "soft_deleted_at",
            ] {
                #expect(lookupColumns.contains(expected), "missing lookup column \(expected)")
            }
        }
    }

    @Test("source_content_origin column defaults to userAuthored (forward seam)")
    func lookupEventHasSourceOriginColumnDefaultingUserAuthored() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { try seedSpace($0) }
        let repository = GRDBDictionaryLookupEventRepository(writer: database.writer)
        try repository.record(event("e1", term: "ephemeral", at: 0))
        let origin = try queue.read { db in
            try String.fetchOne(db, sql: "SELECT source_content_origin FROM dictionary_lookup_events WHERE id = 'e1'")
        }
        #expect(origin == "userAuthored")
    }

    // MARK: - Lookup-event repository

    @Test("events are local-only / excluded from backup and export")
    func lookupEventsExcludedFromBackupAndExport() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { try seedSpace($0) }
        let repository = GRDBDictionaryLookupEventRepository(writer: database.writer)
        try repository.record(event("e1", term: "x", at: 0))
        let row = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT sync_policy, backup_policy, export_policy FROM dictionary_lookup_events WHERE id = 'e1'")
        }
        #expect(row?["sync_policy"] == "localOnly")
        #expect(row?["backup_policy"] == "excludedFromSystemBackup")
        #expect(row?["export_policy"] == "excludedByDefault")
    }

    @Test("windowed read returns active events after a cursor, oldest first")
    func windowedReadAfterCursor() throws {
        let (database, _) = try makeDatabase()
        let repository = GRDBDictionaryLookupEventRepository(writer: database.writer)
        try database.writer.write { try seedSpace($0) }
        try repository.record(event("e1", term: "a", at: 10))
        try repository.record(event("e2", term: "b", at: 20))
        try repository.record(event("e3", term: "c", at: 30))
        try repository.softDelete(id: "e2")

        let afterTen = try repository.events(spaceID: "s1", after: Date(timeIntervalSince1970: 10))
        #expect(afterTen.map(\.id) == ["e3"]) // e2 soft-deleted, e1 not after 10
        let all = try repository.events(spaceID: "s1", after: nil)
        #expect(all.map(\.id) == ["e1", "e3"])
    }

    // MARK: - Analysis ledger cursor

    @Test("incremental recompute skips already-analyzed events via the high-water cursor")
    func cursorIncrementalRecomputeSkipsAlreadyAnalyzed() throws {
        let (database, _) = try makeDatabase()
        let lookups = GRDBDictionaryLookupEventRepository(writer: database.writer)
        let ledger = GRDBAnalysisLedgerRepository(writer: database.writer)
        try database.writer.write { try seedSpace($0) }
        try lookups.record(event("e1", term: "a", at: 10))
        try lookups.record(event("e2", term: "b", at: 20))

        let key = AnalysisLedgerKey(sourceType: "dictionaryLookup", sourceID: "s1", analyzer: "bandSignal", analyzerVersion: 1)
        #expect(try ledger.cursorPosition(key) == 0)
        // Process the first batch, advance the cursor to the latest occurred_at.
        let firstBatch = try lookups.events(spaceID: "s1", after: Date(timeIntervalSince1970: ledger.cursorPosition(key)))
        #expect(firstBatch.map(\.id) == ["e1", "e2"])
        try ledger.advanceCursor(key, to: 20, now: Date(timeIntervalSince1970: 100))

        // A newer event; only it should be seen past the cursor.
        try lookups.record(event("e3", term: "c", at: 30))
        let nextBatch = try lookups.events(spaceID: "s1", after: Date(timeIntervalSince1970: ledger.cursorPosition(key)))
        #expect(nextBatch.map(\.id) == ["e3"])
    }

    @Test("bumping the analyzer version forces a fresh cursor (full re-run)")
    func analyzerVersionBumpForcesRecompute() throws {
        let (database, _) = try makeDatabase()
        let ledger = GRDBAnalysisLedgerRepository(writer: database.writer)
        let v1 = AnalysisLedgerKey(sourceType: "dictionaryLookup", sourceID: "s1", analyzer: "bandSignal", analyzerVersion: 1)
        try ledger.advanceCursor(v1, to: 50, now: Date(timeIntervalSince1970: 100))
        #expect(try ledger.cursorPosition(v1) == 50)
        // A new version is a different ledger row → cursor starts at 0.
        let v2 = AnalysisLedgerKey(sourceType: "dictionaryLookup", sourceID: "s1", analyzer: "bandSignal", analyzerVersion: 2)
        #expect(try ledger.cursorPosition(v2) == 0)
    }

    @Test("cursor advances monotonically and never regresses under re-entry")
    func cursorMonotonicUnderReentry() throws {
        let (database, _) = try makeDatabase()
        let ledger = GRDBAnalysisLedgerRepository(writer: database.writer)
        let key = AnalysisLedgerKey(sourceType: "dictionaryLookup", sourceID: "s1", analyzer: "bandSignal", analyzerVersion: 1)
        try ledger.advanceCursor(key, to: 30, now: Date(timeIntervalSince1970: 100))
        // A stale advance (lower) must not regress the high-water mark.
        try ledger.advanceCursor(key, to: 10, now: Date(timeIntervalSince1970: 200))
        #expect(try ledger.cursorPosition(key) == 30)
        try ledger.advanceCursor(key, to: 40, now: Date(timeIntervalSince1970: 300))
        #expect(try ledger.cursorPosition(key) == 40)
    }
}
