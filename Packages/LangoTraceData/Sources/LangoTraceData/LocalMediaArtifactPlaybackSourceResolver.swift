import Foundation
import LangoTraceCore

public struct LocalMediaArtifactPlaybackSourceResolver: MediaArtifactPlaybackSourceResolving, Sendable {
    private let fileStore: LocalMediaArtifactFileStore

    public init(fileStore: LocalMediaArtifactFileStore) {
        self.fileStore = fileStore
    }

    public func playbackSource(for artifact: MediaArtifact) async throws -> MediaArtifactPlaybackSource {
        guard let info = try fileStore.fileInfo(relativePath: artifact.relativeFilePath) else {
            throw LocalMediaArtifactStoreError.metadataFileMismatch(.fileMissing)
        }
        guard info.byteSize == artifact.byteSize,
              info.contentHash == artifact.contentHash
        else {
            throw LocalMediaArtifactStoreError.metadataFileMismatch(.contentMismatch)
        }
        return MediaArtifactPlaybackSource(
            artifactID: artifact.id,
            fileURL: try fileStore.absoluteURLForInternalUse(relativePath: artifact.relativeFilePath),
            mimeType: artifact.mimeType,
            byteSize: artifact.byteSize,
            contentHash: artifact.contentHash
        )
    }
}
