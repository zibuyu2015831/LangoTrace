import Foundation
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("Local media artifact store facade")
struct LocalMediaArtifactStoreTests {
    @Test("Facade validates moves and commits staged TTS audio artifact")
    func facadeValidatesMovesAndCommitsStagedTTSAudioArtifact() async throws {
        let harness = try await FacadeHarness()
        let staged = try harness.fileStore.writeStagingFile(Data("audio".utf8), operationID: "op-1")
        let input = MediaArtifactTestFixtures.commitInput(stagedFile: staged)

        let artifact = try await harness.store.commitTTSAudioArtifact(input)
        let lookup = try await harness.store.ttsAudioArtifact(for: input.key)

        #expect(artifact.relativeFilePath == "ttsSentenceAudio/en/artifact-1.mp3")
        #expect(try harness.fileStore.fileInfo(relativePath: artifact.relativeFilePath)?.byteSize == 5)
        guard case let .hit(hit) = lookup else {
            Issue.record("Expected facade hit after commit")
            return
        }
        #expect(hit.id == artifact.id)
    }

    @Test("Facade deletes staging and skips metadata when validation fails")
    func facadeDeletesStagingWhenValidationFails() async throws {
        let harness = try await FacadeHarness(validatorResult: .failed(.audioDecodeFailed))
        let staged = try harness.fileStore.writeStagingFile(Data("bad".utf8), operationID: "op-1")
        let input = MediaArtifactTestFixtures.commitInput(stagedFile: staged)

        do {
            _ = try await harness.store.commitTTSAudioArtifact(input)
            Issue.record("Expected validation failure")
        } catch let error as LocalMediaArtifactStoreError {
            #expect(error == .validationFailed(.audioDecodeFailed))
        }

        #expect(try harness.fileStore.fileInfo(relativePath: staged.relativeStagingPath) == nil)
        #expect(try await MediaArtifactTestFixtures.mediaArtifactCount(in: harness.database) == 0)
    }

    @Test("Facade invalidates stale metadata when committed file is missing")
    func facadeInvalidatesStaleMetadataWhenFileMissing() async throws {
        let harness = try await FacadeHarness()
        let staged = try harness.fileStore.writeStagingFile(Data("audio".utf8), operationID: "op-1")
        let input = MediaArtifactTestFixtures.commitInput(stagedFile: staged)
        let artifact = try await harness.store.commitTTSAudioArtifact(input)
        _ = try harness.fileStore.deleteFile(relativePath: artifact.relativeFilePath)

        let lookup = try await harness.store.ttsAudioArtifact(for: input.key)

        #expect(lookup == .invalidated(.fileMissing))
    }

    @Test("Facade cleanup removes files and metadata")
    func facadeCleanupRemovesFilesAndMetadata() async throws {
        let harness = try await FacadeHarness()
        let staged = try harness.fileStore.writeStagingFile(Data("audio".utf8), operationID: "op-1")
        let input = MediaArtifactTestFixtures.commitInput(stagedFile: staged)
        _ = try await harness.store.commitTTSAudioArtifact(input)
        try await harness.repository.invalidateArtifacts(
            MediaArtifactInvalidationRequest(
                languageSpaceID: "space-1",
                artifactType: .ttsSentenceAudio,
                invalidatedAt: Date(timeIntervalSince1970: 600)
            )
        )

        let result = try await harness.store.cleanupArtifacts(
            MediaArtifactCleanupRequest(
                languageSpaceID: "space-1",
                artifactType: .ttsSentenceAudio,
                now: Date(timeIntervalSince1970: 700)
            )
        )

        #expect(result.deletedArtifactCount == 1)
        #expect(result.deletedFileCount == 1)
        #expect(result.reclaimedBytes == 5)
        #expect(try await MediaArtifactTestFixtures.mediaArtifactCount(in: harness.database) == 0)
    }
}

private struct FacadeHarness {
    let database: AppDatabase
    let repository: GRDBMediaArtifactRepository
    let fileStore: LocalMediaArtifactFileStore
    let store: LocalMediaArtifactStore

    init(validatorResult: TTSAudioValidationStatus = .succeeded) async throws {
        database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let idGenerator = MediaArtifactIDGenerator()
        repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: idGenerator.next
        )
        fileStore = try LocalMediaArtifactFileStore(rootDirectory: temporaryRoot())
        store = LocalMediaArtifactStore(
            repository: repository,
            fileStore: fileStore,
            audioFileValidator: FakeTTSAudioFileValidator(status: validatorResult)
        )
    }
}

private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("MediaArtifacts", isDirectory: true)
}

private struct FakeTTSAudioFileValidator: TTSAudioFileValidating {
    var status: TTSAudioValidationStatus

    func validateTTSAudioFile(_ input: TTSAudioFileValidationInput) async -> TTSAudioFileValidationResult {
        switch status {
        case .succeeded:
            TTSAudioFileValidationResult(
                status: .succeeded,
                metadata: TTSAudioMetadata(
                    format: input.declaredFormat,
                    byteCount: Int(input.stagedFile.byteSize),
                    durationSeconds: 1.5,
                    sampleRate: nil
                )
            )
        case let .failed(category):
            TTSAudioFileValidationResult(status: .failed(category), metadata: nil)
        }
    }
}
