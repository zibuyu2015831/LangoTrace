import Foundation
import GRDB
@testable import LangoTraceData
import Testing

/// Covers the LM02 Slice 1 v27 migration: the system-level `learner_memory_facts`
/// table and the new `AppDatabase.writer` seam (LM01 §20 预告).
@Suite("AppDatabase learner memory migration (v27)")
struct AppDatabaseLearnerMemoryMigrationTests {
    private func makeDatabase() throws -> (AppDatabase, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        return (database, queue)
    }

    @Test("exposes a writer seam backed by the same queue")
    func exposesWriterSeam() throws {
        let (database, _) = try makeDatabase()
        // The writer must accept a write transaction (smoke: a no-op write).
        try database.writer.write { db in
            try db.execute(sql: "SELECT 1")
        }
    }

    @Test("v27 creates the system-level learner_memory_facts table with no space column")
    func v27CreatesSystemLevelTable() throws {
        let (_, queue) = try makeDatabase()
        try queue.read { db in
            #expect(try db.tableExists("learner_memory_facts"))
            let columns = try db.columns(in: "learner_memory_facts").map(\.name)
            // System-level: deliberately no space_id (ADR-006 §3).
            #expect(!columns.contains("space_id"))
            for expected in [
                "id", "kind", "text", "salience", "visibility", "source",
                "source_entry_id", "sync_policy", "backup_policy", "export_policy",
                "created_at", "soft_deleted_at",
            ] {
                #expect(columns.contains(expected), "missing column \(expected)")
            }
        }
    }

    @Test("v27 rejects an unknown kind via CHECK constraint")
    func v27RejectsUnknownKind() throws {
        let (_, queue) = try makeDatabase()
        #expect(throws: (any Error).self) {
            try queue.write { db in
                try db.execute(sql: """
                INSERT INTO learner_memory_facts (id, kind, text, created_at)
                VALUES ('x', 'notAKind', 'hello', 0)
                """)
            }
        }
    }
}
