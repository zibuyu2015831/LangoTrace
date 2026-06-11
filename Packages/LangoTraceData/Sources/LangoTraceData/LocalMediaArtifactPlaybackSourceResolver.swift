import Foundation
import LangoTraceCore

public struct LocalMediaArtifactPlaybackSourceResolver: MediaArtifactPlaybackSourceResolving, Sendable {
    private let fileStore: LocalMediaArtifactFileStore

    public init(fileStore: LocalMediaArtifactFileStore) {
        self.fileStore = fileStore
    }

    public func playbackSource(for artifact: MediaArtifact) async throws -> MediaArtifactPlaybackSource {
        // Playback resolution validates the cheap byte size only; hashing the whole
        // file on every resolve is intentionally avoided.
        guard let byteSize = try fileStore.fileByteSize(relativePath: artifact.relativeFilePath) else {
            throw LocalMediaArtifactStoreError.metadataFileMismatch(.fileMissing)
        }
        guard byteSize == artifact.byteSize else {
            throw LocalMediaArtifactStoreError.metadataFileMismatch(.contentMismatch)
        }
        return try MediaArtifactPlaybackSource(
            artifactID: artifact.id,
            fileURL: fileStore.absoluteURLForInternalUse(relativePath: artifact.relativeFilePath),
            mimeType: artifact.mimeType,
            byteSize: artifact.byteSize,
            contentHash: artifact.contentHash
        )
    }
}
