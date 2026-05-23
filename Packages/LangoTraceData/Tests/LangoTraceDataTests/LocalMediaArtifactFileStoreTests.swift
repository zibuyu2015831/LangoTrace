import Foundation
@testable import LangoTraceData
import Testing

@Suite("Local media artifact file store")
struct LocalMediaArtifactFileStoreTests {
    @Test("File store creates backup excluded root and stages files")
    func fileStoreCreatesBackupExcludedRootAndStagesFiles() throws {
        let store = try LocalMediaArtifactFileStore(rootDirectory: temporaryRoot())

        let resourceValues = try store.rootDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        let staged = try store.writeStagingFile(Data("audio".utf8), operationID: "op-1")

        #expect(FileManager.default.fileExists(atPath: store.rootDirectory.path))
        #expect(resourceValues.isExcludedFromBackup == true)
        #expect(staged.relativeStagingPath == "staging/op-1.tmp")
        #expect(staged.byteSize == 5)
        #expect(staged.contentHash.count == 64)
    }

    @Test("File store atomically moves staged files and deletes with reclaimed bytes")
    func fileStoreMovesAndDeletesFiles() throws {
        let store = try LocalMediaArtifactFileStore(rootDirectory: temporaryRoot())
        let staged = try store.writeStagingFile(Data("audio".utf8), operationID: "op-1")

        try store.moveStagedFile(staged, to: "ttsSentenceAudio/space-1/artifact-1.mp3")
        let info = try store.fileInfo(relativePath: "ttsSentenceAudio/space-1/artifact-1.mp3")
        let reclaimed = try store.deleteFile(relativePath: "ttsSentenceAudio/space-1/artifact-1.mp3")

        #expect(info?.byteSize == 5)
        #expect(reclaimed == 5)
        #expect(try store.fileInfo(relativePath: "ttsSentenceAudio/space-1/artifact-1.mp3") == nil)
    }

    @Test("File store rejects traversal and absolute paths")
    func fileStoreRejectsUnsafeRelativePaths() throws {
        let store = try LocalMediaArtifactFileStore(rootDirectory: temporaryRoot())

        #expect(throws: LocalMediaArtifactFileStoreError.unsafeRelativePath) {
            try store.fileInfo(relativePath: "../secret.mp3")
        }
        #expect(throws: LocalMediaArtifactFileStoreError.unsafeRelativePath) {
            try store.fileInfo(relativePath: "/tmp/secret.mp3")
        }
    }

    @Test("File store removes staging leftovers")
    func fileStoreRemovesStagingLeftovers() throws {
        let store = try LocalMediaArtifactFileStore(rootDirectory: temporaryRoot())
        _ = try store.writeStagingFile(Data("audio".utf8), operationID: "op-1")

        let removed = try store.removeStagingFiles()

        #expect(removed.deletedFileCount == 1)
        #expect(removed.reclaimedBytes == 5)
    }
}

private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("MediaArtifacts", isDirectory: true)
}
