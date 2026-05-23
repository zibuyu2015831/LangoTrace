import Foundation
import LangoTraceCore

public enum LocalMediaArtifactStoreError: Error, Equatable, Sendable {
    case validationFailed(AIProviderValidationErrorCategory)
    case metadataFileMismatch(MediaArtifactInvalidationReason)
}

public struct LocalMediaArtifactStore: LocalMediaArtifactStoring, Sendable {
    private let repository: any MediaArtifactRepository
    private let fileStore: LocalMediaArtifactFileStore
    private let audioFileValidator: any TTSAudioFileValidating

    public init(
        repository: any MediaArtifactRepository,
        fileStore: LocalMediaArtifactFileStore,
        audioFileValidator: any TTSAudioFileValidating
    ) {
        self.repository = repository
        self.fileStore = fileStore
        self.audioFileValidator = audioFileValidator
    }

    public func ttsAudioArtifact(for key: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult {
        let lookup = try await repository.ttsAudioArtifactMetadata(for: key)
        guard case let .hit(artifact) = lookup else {
            return lookup
        }

        guard let info = try fileStore.fileInfo(relativePath: artifact.relativeFilePath) else {
            try await invalidate(artifact, reason: .fileMissing)
            return .invalidated(.fileMissing)
        }
        guard info.byteSize == artifact.byteSize,
              info.contentHash == artifact.contentHash
        else {
            try await invalidate(artifact, reason: .contentMismatch)
            return .invalidated(.contentMismatch)
        }
        return .hit(artifact)
    }

    public func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact {
        if case let .hit(existing) = try await ttsAudioArtifact(for: input.key) {
            _ = try fileStore.deleteFile(relativePath: input.stagedFile.relativeStagingPath)
            return existing
        }

        let validation = await audioFileValidator.validateTTSAudioFile(
            TTSAudioFileValidationInput(
                stagedFile: input.stagedFile,
                declaredFormat: input.key.outputFormat,
                mimeType: input.mimeType,
                byteSizeLimit: 25_000_000
            )
        )
        guard validation.status == .succeeded else {
            _ = try fileStore.deleteFile(relativePath: input.stagedFile.relativeStagingPath)
            if case let .failed(category) = validation.status {
                throw LocalMediaArtifactStoreError.validationFailed(category)
            }
            throw LocalMediaArtifactStoreError.validationFailed(.invalidResponse)
        }

        let commitInput = TTSAudioArtifactCommitInput(
            key: input.key,
            languageSpaceID: input.languageSpaceID,
            owner: input.owner,
            stagedFile: input.stagedFile,
            mimeType: input.mimeType,
            durationSeconds: validation.metadata?.durationSeconds ?? input.durationSeconds,
            createdAt: input.createdAt
        )
        let reservation = try await repository.reserveTTSAudioArtifact(commitInput)
        let artifact = reservation.artifact
        do {
            if try fileStore.fileInfo(relativePath: artifact.relativeFilePath) != nil {
                _ = try fileStore.deleteFile(relativePath: input.stagedFile.relativeStagingPath)
            } else {
                try fileStore.moveStagedFile(input.stagedFile, to: artifact.relativeFilePath)
            }
            try await repository.markArtifactFileReady(artifactID: artifact.id, at: input.createdAt)
            return artifact
        } catch {
            if reservation.wasCreated {
                _ = try? fileStore.deleteFile(relativePath: artifact.relativeFilePath)
                try await repository.deleteArtifactMetadata(artifactIDs: [artifact.id])
            } else {
                _ = try? fileStore.deleteFile(relativePath: input.stagedFile.relativeStagingPath)
            }
            throw error
        }
    }

    public func invalidateArtifacts(_ request: MediaArtifactInvalidationRequest) async throws {
        try await repository.invalidateArtifacts(request)
    }

    public func cleanupArtifacts(_ request: MediaArtifactCleanupRequest) async throws -> MediaArtifactCleanupResult {
        let artifacts = try await repository.artifactsForCleanup(request)
        var deletedFiles = 0
        var failedFiles = 0
        var reclaimedBytes: Int64 = 0
        var deletedArtifactIDs: [String] = []

        for artifact in artifacts {
            do {
                let reclaimed = try fileStore.deleteFile(relativePath: artifact.relativeFilePath)
                if reclaimed > 0 {
                    deletedFiles += 1
                }
                reclaimedBytes += reclaimed
                deletedArtifactIDs.append(artifact.id)
            } catch {
                failedFiles += 1
            }
        }

        if !deletedArtifactIDs.isEmpty {
            try await repository.deleteArtifactMetadata(artifactIDs: deletedArtifactIDs)
        }
        let staging = try fileStore.removeStagingFiles()
        return MediaArtifactCleanupResult(
            deletedArtifactCount: deletedArtifactIDs.count,
            deletedFileCount: deletedFiles + staging.deletedFileCount,
            reclaimedBytes: reclaimedBytes + staging.reclaimedBytes,
            failedFileCount: failedFiles + staging.failedFileCount
        )
    }
}

private extension LocalMediaArtifactStore {
    func invalidate(_ artifact: MediaArtifact, reason _: MediaArtifactInvalidationReason) async throws {
        try await repository.invalidateArtifact(artifactID: artifact.id, at: Date())
    }
}
