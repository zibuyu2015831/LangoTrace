import Foundation
import GRDB
import LangoTraceCore

/// Local, non-sensitive export/import engine (E10 Slice 1).
///
/// Exports the user's own main data (entries + deposited memory) as a plain
/// JSON package with a manifest + SHA-256 — no encryption needed because
/// secrets are *excluded*, not protected (核心决策 9; spec 007 §4). Import is
/// verify-before-write: format-version + checksum are checked first, then rows
/// merge with same-id skip (never overwrite). Works on `Data` blobs so it is
/// fully testable without file panels; the macOS file-panel + attachment
/// bundling layer is a separate (deferred) slice.
public struct GRDBLocalExportService: @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    /// Informational DB schema version stamped into the manifest. Tracks the
    /// latest migration; bump when adding exported tables.
    public static let schemaVersion = "v26"

    public init(database: AppDatabase) {
        databaseQueue = database.databaseQueue
    }

    public func exportPackage(spaceID: String) async throws -> PortableExportPackage {
        try await databaseQueue.read { db in
            let entries = try Row.fetchAll(
                db,
                sql: """
                SELECT id, space_id, title, body, source, scene, created_at, updated_at
                FROM entries WHERE space_id = ? AND deleted_at IS NULL
                ORDER BY created_at ASC, id ASC
                """,
                arguments: [spaceID]
            ).map { row in
                PortableEntrySnapshot(
                    id: row["id"], spaceID: row["space_id"], title: row["title"], body: row["body"],
                    source: row["source"], scene: row["scene"],
                    createdAt: Date(timeIntervalSince1970: row["created_at"]),
                    updatedAt: Date(timeIntervalSince1970: row["updated_at"])
                )
            }
            let memories = try Row.fetchAll(
                db,
                sql: """
                SELECT id, space_id, entry_id, kind, text, note, example_target, example_native, difficulty, created_at
                FROM memory_items WHERE space_id = ? AND soft_deleted_at IS NULL
                ORDER BY created_at ASC, id ASC
                """,
                arguments: [spaceID]
            ).map { row in
                PortableMemorySnapshot(
                    id: row["id"], spaceID: row["space_id"], entryID: row["entry_id"], kind: row["kind"],
                    text: row["text"], note: row["note"], exampleTarget: row["example_target"],
                    exampleNative: row["example_native"], difficulty: row["difficulty"],
                    createdAt: Date(timeIntervalSince1970: row["created_at"])
                )
            }
            let manifest = ExportManifest(
                formatVersion: LangoTraceExportFormat.currentFormatVersion,
                schemaVersion: Self.schemaVersion,
                spaceID: spaceID,
                entryCount: entries.count,
                memoryCount: memories.count,
                payloadChecksum: LangoTraceExportFormat.payloadChecksum(entries: entries, memories: memories)
            )
            return PortableExportPackage(manifest: manifest, entries: entries, memories: memories)
        }
    }

    public func exportPackageData(spaceID: String) async throws -> Data {
        let package = try await exportPackage(spaceID: spaceID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(package)
    }

    /// Parses + verifies a package (format version, checksum) without writing.
    public func preview(packageData: Data) throws -> ImportPreview {
        let package = try Self.decodeAndVerify(packageData)
        return ImportPreview(
            entryCount: package.entries.count,
            memoryCount: package.memories.count,
            spaceID: package.manifest.spaceID
        )
    }

    /// Verifies then merges into the package's space with same-id skip.
    public func importPackage(packageData: Data) async throws -> ImportResult {
        let package = try Self.decodeAndVerify(packageData)
        return try await databaseQueue.write { db in
            var importedEntries = 0
            var skippedEntries = 0
            for entry in package.entries {
                let changed = try Self.insertOrIgnoreEntry(entry, in: db)
                if changed { importedEntries += 1 } else { skippedEntries += 1 }
            }
            var importedMemories = 0
            var skippedMemories = 0
            for memory in package.memories {
                let changed = try Self.insertOrIgnoreMemory(memory, in: db)
                if changed { importedMemories += 1 } else { skippedMemories += 1 }
            }
            return ImportResult(
                importedEntries: importedEntries,
                skippedEntries: skippedEntries,
                importedMemories: importedMemories,
                skippedMemories: skippedMemories
            )
        }
    }
}

private extension GRDBLocalExportService {
    static func decodeAndVerify(_ data: Data) throws -> PortableExportPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let package = try? decoder.decode(PortableExportPackage.self, from: data) else {
            throw ImportError(reason: .malformed)
        }
        guard package.manifest.formatVersion <= LangoTraceExportFormat.currentFormatVersion else {
            throw ImportError(reason: .unsupportedFormatVersion)
        }
        let checksum = LangoTraceExportFormat.payloadChecksum(entries: package.entries, memories: package.memories)
        guard checksum == package.manifest.payloadChecksum else {
            throw ImportError(reason: .checksumMismatch)
        }
        return package
    }

    static func insertOrIgnoreEntry(_ entry: PortableEntrySnapshot, in db: Database) throws -> Bool {
        try db.execute(
            sql: """
            INSERT OR IGNORE INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                entry.id, entry.spaceID, entry.title, entry.body, entry.source, entry.scene,
                entry.createdAt.timeIntervalSince1970, entry.updatedAt.timeIntervalSince1970,
            ]
        )
        return db.changesCount > 0
    }

    static func insertOrIgnoreMemory(_ memory: PortableMemorySnapshot, in db: Database) throws -> Bool {
        try db.execute(
            sql: """
            INSERT OR IGNORE INTO memory_items
            (id, space_id, entry_id, source_kind, source_candidate_id, kind, text, note,
             example_target, example_native, difficulty, review_state, review_rung,
             review_due_at, last_reviewed_at, review_count, mastered_at, created_at)
            VALUES (?, ?, ?, 'candidate', NULL, ?, ?, ?, ?, ?, ?, 'new', 0, NULL, NULL, 0, NULL, ?)
            """,
            arguments: [
                memory.id, memory.spaceID, memory.entryID, memory.kind, memory.text, memory.note,
                memory.exampleTarget, memory.exampleNative, memory.difficulty,
                memory.createdAt.timeIntervalSince1970,
            ]
        )
        return db.changesCount > 0
    }
}

/// Error carrying the import rejection reason.
public struct ImportError: Error, Equatable, Sendable {
    public var reason: ImportRejectionReason
    public init(reason: ImportRejectionReason) {
        self.reason = reason
    }
}
