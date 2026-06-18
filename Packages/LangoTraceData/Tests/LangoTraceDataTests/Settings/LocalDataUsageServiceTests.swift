import Foundation
import LangoTraceCore
@testable import LangoTraceData
import Testing

/// E12 Slice A: the local data usage service sums the database file (plus WAL/SHM siblings)
/// and the MediaArtifacts directory, tolerating absent paths with a zero contribution.
@Suite("Local data usage service")
struct LocalDataUsageServiceTests {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("langotrace-usage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ byteCount: Int, to url: URL) throws {
        try Data(repeating: 0x41, count: byteCount).write(to: url)
    }

    @Test("missing database and media directory yield zero usage")
    func missingPathsYieldZero() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = LocalDataUsageService(
            databaseURL: root.appendingPathComponent("absent.sqlite"),
            mediaArtifactsRoot: root.appendingPathComponent("AbsentMedia", isDirectory: true)
        )
        #expect(await service.computeUsage().totalBytes == 0)
    }

    @Test("usage sums the database file and media artifacts directory contents")
    func sumsDatabaseAndMedia() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let dbURL = root.appendingPathComponent("LangoTrace.sqlite")
        try write(4096, to: dbURL)
        try write(1024, to: URL(fileURLWithPath: dbURL.path + "-wal"))

        let mediaRoot = root.appendingPathComponent("MediaArtifacts", isDirectory: true)
        let nested = mediaRoot.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try write(2048, to: nested.appendingPathComponent("a.bin"))

        let service = LocalDataUsageService(databaseURL: dbURL, mediaArtifactsRoot: mediaRoot)
        let usage = await service.computeUsage()
        // Allocation granularity rounds each file up to a block, so assert a lower bound on
        // the real bytes written rather than an exact total.
        #expect(usage.totalBytes >= 4096 + 1024 + 2048)
    }
}
