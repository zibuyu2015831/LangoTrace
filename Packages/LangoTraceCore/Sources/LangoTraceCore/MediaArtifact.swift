import Foundation

public struct MediaArtifact: Equatable, Sendable {
    public var id: String
    public var languageSpaceID: String
    public var owner: MediaArtifactOwner
    public var type: MediaArtifactType
    public var derivationKind: MediaArtifactDerivationKind
    public var derivationKeyHash: String
    public var relativeFilePath: String
    public var mimeType: String
    public var byteSize: Int64
    public var durationSeconds: Double?
    public var contentHash: String
    public var createdAt: Date
    public var lastAccessedAt: Date
    public var invalidatedAt: Date?
    public var deleteAfter: Date?
    public var policy: MediaArtifactPolicy

    public init(
        id: String,
        languageSpaceID: String,
        owner: MediaArtifactOwner,
        type: MediaArtifactType,
        derivationKind: MediaArtifactDerivationKind,
        derivationKeyHash: String,
        relativeFilePath: String,
        mimeType: String,
        byteSize: Int64,
        durationSeconds: Double?,
        contentHash: String,
        createdAt: Date,
        lastAccessedAt: Date,
        invalidatedAt: Date? = nil,
        deleteAfter: Date? = nil,
        policy: MediaArtifactPolicy = .defaultDerivedMediaPolicy
    ) {
        self.id = id
        self.languageSpaceID = languageSpaceID
        self.owner = owner
        self.type = type
        self.derivationKind = derivationKind
        self.derivationKeyHash = derivationKeyHash
        self.relativeFilePath = relativeFilePath
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.durationSeconds = durationSeconds
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.invalidatedAt = invalidatedAt
        self.deleteAfter = deleteAfter
        self.policy = policy
    }
}

public enum MediaArtifactOwner: Equatable, Sendable {
    case entry(id: String)
    case learningMaterial(id: String)
    case learningMaterialSentence(materialID: String, sentenceIndex: Int)
    case readingDocumentSentence(documentID: String, sentenceID: String)
    case practiceSession(id: String)
    case temporaryOperation(id: String)
}

public enum MediaArtifactType: String, CaseIterable, Sendable {
    case ttsSentenceAudio
    case ttsDocumentAudio
    case shadowingRecording
    case dictationRecording
    case ocrIntermediate
    case exportTemporary
    case entryPhotoOriginal
    case entryPhotoThumbnail
}

public enum MediaArtifactDerivationKind: String, CaseIterable, Sendable {
    case ttsAudio
    case practiceRecording
    case photoImage
}

public struct MediaArtifactPolicy: Equatable, Sendable {
    public var backupPolicy: MediaArtifactBackupPolicy
    public var syncPolicy: MediaArtifactSyncPolicy
    public var exportPolicy: MediaArtifactExportPolicy

    public init(
        backupPolicy: MediaArtifactBackupPolicy,
        syncPolicy: MediaArtifactSyncPolicy,
        exportPolicy: MediaArtifactExportPolicy
    ) {
        self.backupPolicy = backupPolicy
        self.syncPolicy = syncPolicy
        self.exportPolicy = exportPolicy
    }

    public static let defaultDerivedMediaPolicy = MediaArtifactPolicy(
        backupPolicy: .excludedFromSystemBackup,
        syncPolicy: .localOnly,
        exportPolicy: .excludedByDefault
    )

    /// Photo originals are primary user assets: same policy values as derived media,
    /// but callers must never set deleteAfter on rows using this policy.
    public static let photoOriginalPolicy = MediaArtifactPolicy(
        backupPolicy: .excludedFromSystemBackup,
        syncPolicy: .localOnly,
        exportPolicy: .excludedByDefault
    )
}

public enum MediaArtifactBackupPolicy: String, CaseIterable, Sendable {
    case excludedFromSystemBackup
    case includedInSystemBackup
}

public enum MediaArtifactSyncPolicy: String, CaseIterable, Sendable {
    case localOnly
    case syncCandidate
    case syncManaged
}

public enum MediaArtifactExportPolicy: String, CaseIterable, Sendable {
    case excludedByDefault
    case includedInUserExport
    case includedInRecoverableBackup
}

public enum MediaArtifactLookupResult: Equatable, Sendable {
    case hit(MediaArtifact)
    case miss
    case invalidated(MediaArtifactInvalidationReason)
}

public enum MediaArtifactInvalidationReason: String, CaseIterable, Sendable {
    case explicitlyInvalidated
    case fileMissing
    case fileUnreadable
    case contentMismatch
    case decodeFailed
    case configurationChanged
}

public struct MediaArtifactStagedFileReference: Equatable, Sendable {
    public var relativeStagingPath: String
    public var byteSize: Int64
    public var contentHash: String

    public init(relativeStagingPath: String, byteSize: Int64, contentHash: String) {
        self.relativeStagingPath = relativeStagingPath
        self.byteSize = byteSize
        self.contentHash = contentHash
    }
}

public struct MediaArtifactInvalidationRequest: Equatable, Sendable {
    public var languageSpaceID: String?
    public var owner: MediaArtifactOwner?
    public var artifactType: MediaArtifactType?
    public var providerProfileID: String?
    public var ttsEndpointID: String?
    public var configurationFingerprint: String?
    public var invalidatedAt: Date

    public init(
        languageSpaceID: String? = nil,
        owner: MediaArtifactOwner? = nil,
        artifactType: MediaArtifactType? = nil,
        providerProfileID: String? = nil,
        ttsEndpointID: String? = nil,
        configurationFingerprint: String? = nil,
        invalidatedAt: Date
    ) {
        self.languageSpaceID = languageSpaceID
        self.owner = owner
        self.artifactType = artifactType
        self.providerProfileID = providerProfileID
        self.ttsEndpointID = ttsEndpointID
        self.configurationFingerprint = configurationFingerprint
        self.invalidatedAt = invalidatedAt
    }
}

public struct MediaArtifactCleanupRequest: Equatable, Sendable {
    public var languageSpaceID: String?
    public var owner: MediaArtifactOwner?
    public var artifactType: MediaArtifactType?
    public var includeInvalidated: Bool
    public var now: Date
    public var targetMaximumBytes: Int64?

    public init(
        languageSpaceID: String? = nil,
        owner: MediaArtifactOwner? = nil,
        artifactType: MediaArtifactType? = nil,
        includeInvalidated: Bool = true,
        now: Date,
        targetMaximumBytes: Int64? = nil
    ) {
        self.languageSpaceID = languageSpaceID
        self.owner = owner
        self.artifactType = artifactType
        self.includeInvalidated = includeInvalidated
        self.now = now
        self.targetMaximumBytes = targetMaximumBytes
    }
}

public struct MediaArtifactCleanupResult: Equatable, Sendable {
    public var deletedArtifactCount: Int
    public var deletedFileCount: Int
    public var reclaimedBytes: Int64
    public var failedFileCount: Int

    public init(
        deletedArtifactCount: Int,
        deletedFileCount: Int,
        reclaimedBytes: Int64,
        failedFileCount: Int
    ) {
        self.deletedArtifactCount = deletedArtifactCount
        self.deletedFileCount = deletedFileCount
        self.reclaimedBytes = reclaimedBytes
        self.failedFileCount = failedFileCount
    }
}

public struct MediaArtifactCommitReservation: Equatable, Sendable {
    public var artifact: MediaArtifact
    public var wasCreated: Bool

    public init(artifact: MediaArtifact, wasCreated: Bool) {
        self.artifact = artifact
        self.wasCreated = wasCreated
    }
}

public protocol MediaArtifactRepository: Sendable {
    func ttsAudioArtifactMetadata(for key: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult
    func practiceRecordingArtifactMetadata(for key: PracticeRecordingArtifactKey) async throws -> MediaArtifactLookupResult
    func reserveTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifactCommitReservation
    func reservePracticeRecordingArtifact(_ input: PracticeRecordingArtifactCommitInput) async throws -> MediaArtifactCommitReservation
    func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact
    func commitPracticeRecordingArtifact(_ input: PracticeRecordingArtifactCommitInput) async throws -> MediaArtifact
    func markArtifactFileReady(artifactID: String, at date: Date) async throws
    func invalidateArtifact(artifactID: String, at date: Date) async throws
    func invalidateArtifacts(_ request: MediaArtifactInvalidationRequest) async throws
    func artifactsForCleanup(_ request: MediaArtifactCleanupRequest) async throws -> [MediaArtifact]
    func deleteArtifactMetadata(artifactIDs: [String]) async throws
    func markAccessed(artifactID: String, at date: Date) async throws
}

public protocol LocalMediaArtifactStoring: Sendable {
    func ttsAudioArtifact(for key: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult
    func practiceRecordingArtifact(for key: PracticeRecordingArtifactKey) async throws -> MediaArtifactLookupResult
    func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact
    func commitPracticeRecordingArtifact(_ input: PracticeRecordingArtifactCommitInput) async throws -> MediaArtifact
    func invalidateArtifacts(_ request: MediaArtifactInvalidationRequest) async throws
    func cleanupArtifacts(_ request: MediaArtifactCleanupRequest) async throws -> MediaArtifactCleanupResult
}
