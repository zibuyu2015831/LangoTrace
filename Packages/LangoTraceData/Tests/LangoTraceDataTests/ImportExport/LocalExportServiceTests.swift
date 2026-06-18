import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// Covers the E10 Slice 1 export/import engine: roundtrip restore, same-id skip
/// merge, verify-before-write (checksum + format version), and the secret
/// exclusion guarantee.
@Suite("Local export/import service")
struct LocalExportServiceTests {
    private func makeDatabase(space: String = "space-1") throws -> AppDatabase {
        let database = try AppDatabase.inMemory()
        try database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO language_spaces
                (id, native_language_code, target_language_code, level, display_name, display_name_normalized, created_at, updated_at)
                VALUES (?, 'zh-Hans', 'en', 'b1', 's', 's', 0, 0)
                """,
                arguments: [space]
            )
        }
        return database
    }

    private func seedEntry(_ db: Database, id: String, space: String = "space-1") throws {
        try db.execute(
            sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
            VALUES (?, ?, ?, 'body', 'typedText', '生活', 1, 1)
            """,
            arguments: [id, space, "Title \(id)"]
        )
    }

    @Test("export then import into a fresh space restores entries and memory")
    func roundTripRestores() async throws {
        let source = try makeDatabase()
        try await source.databaseQueue.write { db in
            try seedEntry(db, id: "e1")
            try seedEntry(db, id: "e2")
        }
        let memoryRepo = GRDBMemoryItemRepository(database: source)
        _ = try await memoryRepo.deposit(MemoryDepositInput(
            spaceID: "space-1", entryID: "e1", sourceCandidateID: "c1", kind: .wordPhrase,
            text: "croissant", note: "pastry", exampleTarget: "t", exampleNative: "n", difficulty: .easy
        ))

        let exporter = GRDBLocalExportService(database: source)
        let data = try await exporter.exportPackageData(spaceID: "space-1")

        // Fresh DB with the same space → import.
        let target = try makeDatabase()
        let importer = GRDBLocalExportService(database: target)
        let preview = try importer.preview(packageData: data)
        #expect(preview.entryCount == 2)
        #expect(preview.memoryCount == 1)

        let result = try await importer.importPackage(packageData: data)
        #expect(result.importedEntries == 2)
        #expect(result.importedMemories == 1)

        let restoredEntries = try await target.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM entries WHERE space_id = 'space-1'") ?? 0
        }
        #expect(restoredEntries == 2)
        #expect(try await GRDBMemoryItemRepository(database: target).listMemoryItems(spaceID: "space-1").count == 1)
    }

    @Test("re-importing the same package skips existing rows (same-id merge)")
    func reimportSkips() async throws {
        let source = try makeDatabase()
        try await source.databaseQueue.write { db in try seedEntry(db, id: "e1") }
        let exporter = GRDBLocalExportService(database: source)
        let data = try await exporter.exportPackageData(spaceID: "space-1")

        _ = try await exporter.importPackage(packageData: data)
        let second = try await exporter.importPackage(packageData: data)
        #expect(second.importedEntries == 0)
        #expect(second.skippedEntries == 1)
    }

    @Test("a tampered package fails the checksum check before writing")
    func tamperedRejected() async throws {
        let source = try makeDatabase()
        try await source.databaseQueue.write { db in try seedEntry(db, id: "e1") }
        let data = try await GRDBLocalExportService(database: source).exportPackageData(spaceID: "space-1")
        // Tamper the entry title in the JSON payload, leaving the manifest checksum stale.
        var text = String(decoding: data, as: UTF8.self)
        text = text.replacingOccurrences(of: "Title e1", with: "Tampered")
        let tampered = Data(text.utf8)

        let target = try makeDatabase()
        let importer = GRDBLocalExportService(database: target)
        do {
            _ = try await importer.importPackage(packageData: tampered)
            Issue.record("expected checksum rejection")
        } catch let error as ImportError {
            #expect(error.reason == .checksumMismatch)
        }
    }

    @Test("a higher format version is rejected")
    func higherFormatVersionRejected() throws {
        let entries = [PortableEntrySnapshot(id: "e1", spaceID: "s", title: "t", body: "b", source: "typedText", scene: "x", createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))]
        let manifest = ExportManifest(
            formatVersion: LangoTraceExportFormat.currentFormatVersion + 1,
            schemaVersion: "v999", spaceID: "s", entryCount: 1, memoryCount: 0,
            payloadChecksum: LangoTraceExportFormat.payloadChecksum(entries: entries, memories: [])
        )
        let package = PortableExportPackage(manifest: manifest, entries: entries, memories: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(package)

        let importer = try GRDBLocalExportService(database: makeDatabase())
        do {
            _ = try importer.preview(packageData: data)
            Issue.record("expected format-version rejection")
        } catch let error as ImportError {
            #expect(error.reason == .unsupportedFormatVersion)
        }
    }

    @Test("the export package contains no credential / keychain material")
    func noSecretsInExport() async throws {
        let source = try makeDatabase()
        try await source.databaseQueue.write { db in try seedEntry(db, id: "e1") }
        let data = try await GRDBLocalExportService(database: source).exportPackageData(spaceID: "space-1")
        let text = String(decoding: data, as: UTF8.self).lowercased()
        #expect(!text.contains("keychain"))
        #expect(!text.contains("secret"))
        #expect(!text.contains("api_key"))
    }
}
