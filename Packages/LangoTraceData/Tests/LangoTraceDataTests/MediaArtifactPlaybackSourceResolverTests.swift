import Foundation
import LangoTraceCore
import LangoTraceData
import Testing

@Suite("Media artifact playback source resolver")
struct MediaArtifactPlaybackSourceResolverTests {
    @Test("File store writes TTS staging through Core protocol without exposing absolute paths")
    func fileStoreWritesTTSStagingThroughCoreProtocol() async throws {
        let fileStore = try LocalMediaArtifactFileStore(rootDirectory: temporaryDirectory())
        let writer: any TTSAudioStagingWriting = fileStore

        let staged = try await writer.writeTTSAudioToStaging(Data([1, 2, 3]), preferredExtension: "mp3")

        #expect(staged.relativeStagingPath.hasPrefix("staging/"))
        #expect(staged.relativeStagingPath.hasSuffix(".mp3"))
        #expect(!staged.relativeStagingPath.hasPrefix("/"))
        #expect(staged.byteSize == 3)
        #expect(staged.contentHash.count == 64)
    }

    @Test("Resolver returns ready playback source only when file metadata matches artifact")
    func resolverReturnsReadyPlaybackSource() async throws {
        let fileStore = try LocalMediaArtifactFileStore(rootDirectory: temporaryDirectory())
        let staged = try fileStore.writeStagingFile(Data([0x49, 0x44, 0x33]), operationID: "ready")
        try fileStore.moveStagedFile(staged, to: "tts/space-1/artifact.mp3")
        let artifact = mediaArtifact(
            relativeFilePath: "tts/space-1/artifact.mp3",
            byteSize: staged.byteSize,
            contentHash: staged.contentHash
        )
        let resolver = LocalMediaArtifactPlaybackSourceResolver(fileStore: fileStore)

        let source = try await resolver.playbackSource(for: artifact)

        #expect(source.artifactID == "artifact-1")
        #expect(source.fileURL.lastPathComponent == "artifact.mp3")
        #expect(source.mimeType == "audio/mpeg")
        #expect(source.byteSize == 3)
        #expect(source.contentHash == staged.contentHash)
    }

    @Test("Resolver rejects missing and mismatched artifact files")
    func resolverRejectsMissingAndMismatchedFiles() async throws {
        let fileStore = try LocalMediaArtifactFileStore(rootDirectory: temporaryDirectory())
        let resolver = LocalMediaArtifactPlaybackSourceResolver(fileStore: fileStore)
        let missing = mediaArtifact(relativeFilePath: "tts/missing.mp3", byteSize: 3, contentHash: "missing")

        await #expect(throws: LocalMediaArtifactStoreError.metadataFileMismatch(.fileMissing)) {
            _ = try await resolver.playbackSource(for: missing)
        }

        let staged = try fileStore.writeStagingFile(Data([1]), operationID: "mismatch")
        try fileStore.moveStagedFile(staged, to: "tts/mismatch.mp3")
        let mismatched = mediaArtifact(relativeFilePath: "tts/mismatch.mp3", byteSize: 99, contentHash: "wrong")

        await #expect(throws: LocalMediaArtifactStoreError.metadataFileMismatch(.contentMismatch)) {
            _ = try await resolver.playbackSource(for: mismatched)
        }
    }
}

private func mediaArtifact(
    relativeFilePath: String,
    byteSize: Int64,
    contentHash: String
) -> MediaArtifact {
    MediaArtifact(
        id: "artifact-1",
        languageSpaceID: "space-1",
        owner: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        type: .ttsSentenceAudio,
        derivationKind: .ttsAudio,
        derivationKeyHash: "derivation-key",
        relativeFilePath: relativeFilePath,
        mimeType: "audio/mpeg",
        byteSize: byteSize,
        durationSeconds: 0.4,
        contentHash: contentHash,
        createdAt: Date(timeIntervalSince1970: 0),
        lastAccessedAt: Date(timeIntervalSince1970: 0),
        policy: .defaultDerivedMediaPolicy
    )
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("LangoTraceDataTests-\(UUID().uuidString)", isDirectory: true)
}
