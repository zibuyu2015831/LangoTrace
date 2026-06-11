import CryptoKit
import Foundation
import LangoTraceCore

public struct LocalMediaArtifactFileInfo: Equatable, Sendable {
    public var byteSize: Int64
    public var contentHash: String

    public init(byteSize: Int64, contentHash: String) {
        self.byteSize = byteSize
        self.contentHash = contentHash
    }
}

public enum LocalMediaArtifactFileStoreError: Error, Equatable, Sendable {
    case unsafeRelativePath
    case missingStagedFile
}

public struct LocalMediaArtifactFileStore: TTSAudioStagingWriting, @unchecked Sendable {
    public let rootDirectory: URL
    private let fileManager: FileManager
    private let clock: @Sendable () -> Date

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        clock: @escaping @Sendable () -> Date = Date.init
    ) throws {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.clock = clock
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var root = rootDirectory
        try root.setResourceValues(values)
    }

    public func writeStagingFile(_ data: Data, operationID: String) throws -> MediaArtifactStagedFileReference {
        let relativePath = "staging/\(operationID).tmp"
        let url = try url(for: relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return MediaArtifactStagedFileReference(
            relativeStagingPath: relativePath,
            byteSize: Int64(data.count),
            contentHash: Self.sha256Hex(data)
        )
    }

    public func writeTTSAudioToStaging(
        _ data: Data,
        preferredExtension: String
    ) async throws -> MediaArtifactStagedFileReference {
        let safeExtension = Self.safeFileExtension(preferredExtension)
        let relativePath = "staging/\(UUID().uuidString).\(safeExtension)"
        let url = try url(for: relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return MediaArtifactStagedFileReference(
            relativeStagingPath: relativePath,
            byteSize: Int64(data.count),
            contentHash: Self.sha256Hex(data)
        )
    }

    public func moveStagedFile(_ stagedFile: MediaArtifactStagedFileReference, to relativePath: String) throws {
        let source = try url(for: stagedFile.relativeStagingPath)
        let destination = try url(for: relativePath)
        guard fileManager.fileExists(atPath: source.path) else {
            throw LocalMediaArtifactFileStoreError.missingStagedFile
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
    }

    public func deleteFile(relativePath: String) throws -> Int64 {
        let url = try url(for: relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            return 0
        }
        let size = try byteSize(at: url)
        try fileManager.removeItem(at: url)
        return size
    }

    public func fileInfo(relativePath: String) throws -> LocalMediaArtifactFileInfo? {
        let url = try url(for: relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return LocalMediaArtifactFileInfo(byteSize: Int64(data.count), contentHash: Self.sha256Hex(data))
    }

    public func fileByteSize(relativePath: String) throws -> Int64? {
        let url = try url(for: relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try byteSize(at: url)
    }

    public func removeStagingFiles() throws -> MediaArtifactCleanupResult {
        let stagingURL = try url(for: "staging")
        guard fileManager.fileExists(atPath: stagingURL.path) else {
            return MediaArtifactCleanupResult(
                deletedArtifactCount: 0,
                deletedFileCount: 0,
                reclaimedBytes: 0,
                failedFileCount: 0
            )
        }

        var deleted = 0
        var failed = 0
        var reclaimed: Int64 = 0
        let protectionCutoff = clock().addingTimeInterval(-Self.stagingFileProtectionSeconds)
        let files = try fileManager.contentsOfDirectory(
            at: stagingURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for file in files {
            do {
                // Protect freshly staged files that may still belong to in-flight commits.
                guard try modificationDate(at: file) <= protectionCutoff else {
                    continue
                }
                reclaimed += try byteSize(at: file)
                try fileManager.removeItem(at: file)
                deleted += 1
            } catch {
                failed += 1
            }
        }
        return MediaArtifactCleanupResult(
            deletedArtifactCount: 0,
            deletedFileCount: deleted,
            reclaimedBytes: reclaimed,
            failedFileCount: failed
        )
    }

    public func absoluteURLForInternalUse(relativePath: String) throws -> URL {
        try url(for: relativePath)
    }
}

private extension LocalMediaArtifactFileStore {
    static let stagingFileProtectionSeconds: TimeInterval = 3600

    func url(for relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..")
        else {
            throw LocalMediaArtifactFileStoreError.unsafeRelativePath
        }
        let url = rootDirectory.appendingPathComponent(relativePath)
        let standardizedRoot = rootDirectory.standardizedFileURL.path
        let rootPrefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"
        let standardizedURL = url.standardizedFileURL.path
        guard standardizedURL.hasPrefix(rootPrefix) else {
            throw LocalMediaArtifactFileStoreError.unsafeRelativePath
        }
        return url
    }

    func byteSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    func modificationDate(at url: URL) throws -> Date {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date ?? .distantPast
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func safeFileExtension(_ value: String) -> String {
        let sanitized = value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return sanitized.isEmpty ? "audio" : String(sanitized.prefix(12))
    }
}
