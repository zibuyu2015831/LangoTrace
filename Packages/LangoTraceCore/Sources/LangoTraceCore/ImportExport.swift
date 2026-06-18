import CryptoKit
import Foundation

/// Portable snapshot of one entry (E10 export). Plain, non-sensitive user
/// main data — no credentials, no derived/diagnostic fields. Decoding tolerates
/// unknown future fields (JSONDecoder ignores extras), so older readers survive
/// newer packages on the same format version.
public struct PortableEntrySnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var spaceID: String
    public var title: String
    public var body: String
    public var source: String
    public var scene: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, spaceID: String, title: String, body: String, source: String, scene: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.spaceID = spaceID
        self.title = title
        self.body = body
        self.source = source
        self.scene = scene
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Portable snapshot of one deposited memory item (E10 export).
public struct PortableMemorySnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var spaceID: String
    public var entryID: String?
    public var kind: String
    public var text: String
    public var note: String
    public var exampleTarget: String
    public var exampleNative: String
    public var difficulty: String
    public var createdAt: Date

    public init(id: String, spaceID: String, entryID: String?, kind: String, text: String, note: String, exampleTarget: String, exampleNative: String, difficulty: String, createdAt: Date) {
        self.id = id
        self.spaceID = spaceID
        self.entryID = entryID
        self.kind = kind
        self.text = text
        self.note = note
        self.exampleTarget = exampleTarget
        self.exampleNative = exampleNative
        self.difficulty = difficulty
        self.createdAt = createdAt
    }
}

/// Export package manifest: format version (gates import compatibility), the
/// DB schema version it was taken from (informational), the source space, object
/// counts, and a SHA-256 over the canonical payload for tamper/corruption checks.
public struct ExportManifest: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var schemaVersion: String
    public var spaceID: String
    public var entryCount: Int
    public var memoryCount: Int
    public var payloadChecksum: String

    public init(formatVersion: Int, schemaVersion: String, spaceID: String, entryCount: Int, memoryCount: Int, payloadChecksum: String) {
        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
        self.spaceID = spaceID
        self.entryCount = entryCount
        self.memoryCount = memoryCount
        self.payloadChecksum = payloadChecksum
    }
}

/// A complete portable export package: manifest + the non-sensitive main-data
/// snapshots. Secrets (Keychain), derived indexes (FTS/vector), diagnostic logs,
/// and device-local state are deliberately absent (核心决策 9/12; spec 007 §4).
public struct PortableExportPackage: Codable, Equatable, Sendable {
    public var manifest: ExportManifest
    public var entries: [PortableEntrySnapshot]
    public var memories: [PortableMemorySnapshot]

    public init(manifest: ExportManifest, entries: [PortableEntrySnapshot], memories: [PortableMemorySnapshot]) {
        self.manifest = manifest
        self.entries = entries
        self.memories = memories
    }
}

/// Why an import package was rejected before any write (zero-write-before-verify).
public enum ImportRejectionReason: String, Equatable, Sendable {
    case malformed
    case checksumMismatch
    case unsupportedFormatVersion
}

/// Preview of what an import would do, shown before the user confirms.
public struct ImportPreview: Equatable, Sendable {
    public var entryCount: Int
    public var memoryCount: Int
    public var spaceID: String

    public init(entryCount: Int, memoryCount: Int, spaceID: String) {
        self.entryCount = entryCount
        self.memoryCount = memoryCount
        self.spaceID = spaceID
    }
}

/// Outcome of a merge import (same-id rows are skipped, not overwritten).
public struct ImportResult: Equatable, Sendable {
    public var importedEntries: Int
    public var skippedEntries: Int
    public var importedMemories: Int
    public var skippedMemories: Int

    public init(importedEntries: Int, skippedEntries: Int, importedMemories: Int, skippedMemories: Int) {
        self.importedEntries = importedEntries
        self.skippedEntries = skippedEntries
        self.importedMemories = importedMemories
        self.skippedMemories = skippedMemories
    }
}

/// Shared export-format constants + canonical checksum (used by writer + reader).
public enum LangoTraceExportFormat {
    /// Bumped only on incompatible package layout changes. Import rejects higher.
    public static let currentFormatVersion = 1

    /// Deterministic SHA-256 (hex) over the payload snapshots — sorted by id so
    /// the checksum is stable regardless of row order.
    public static func payloadChecksum(entries: [PortableEntrySnapshot], memories: [PortableMemorySnapshot]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let sortedEntries = entries.sorted { $0.id < $1.id }
        let sortedMemories = memories.sorted { $0.id < $1.id }
        let entryData = (try? encoder.encode(sortedEntries)) ?? Data()
        let memoryData = (try? encoder.encode(sortedMemories)) ?? Data()
        var hasher = SHA256()
        hasher.update(data: entryData)
        hasher.update(data: memoryData)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
