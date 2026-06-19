import Foundation
import LangoTraceCore

/// Computes the on-device storage footprint of the user's main data: the SQLite database
/// (plus its `-wal` / `-shm` siblings) and the `MediaArtifacts` directory (E12 goal 4).
///
/// The computation walks the filesystem and is `async` so callers run it off the main
/// thread; the render path reads a cached `LocalDataUsage` and shows a computing placeholder
/// until the first result lands (spec 004: rendering is never blocked on IO). Missing paths
/// contribute 0 rather than throwing, so a fresh install or absent media directory yields a
/// stable zero usage instead of an error.
public struct LocalDataUsageService: Sendable {
    private let databaseURL: URL
    private let mediaArtifactsRoot: URL

    public init(databaseURL: URL, mediaArtifactsRoot: URL) {
        self.databaseURL = databaseURL
        self.mediaArtifactsRoot = mediaArtifactsRoot
    }

    public func computeUsage(fileManager: FileManager = .default) async -> LocalDataUsage {
        var total: Int64 = 0
        // Database file plus the WAL/SHM siblings, which can dominate before a checkpoint.
        for suffix in ["", "-wal", "-shm"] {
            let url = suffix.isEmpty
                ? databaseURL
                : URL(fileURLWithPath: databaseURL.path + suffix)
            total += Self.fileSize(at: url, fileManager: fileManager)
        }
        total += Self.directorySize(at: mediaArtifactsRoot, fileManager: fileManager)
        return LocalDataUsage(totalBytes: total)
    }

    private static func fileSize(at url: URL, fileManager _: FileManager) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
    }

    private static func directorySize(at root: URL, fileManager: FileManager) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return 0
        }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
    }
}
