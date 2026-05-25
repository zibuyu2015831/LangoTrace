import CryptoKit
import Foundation

public enum PracticeRecordingFormat: String, CaseIterable, Sendable {
    case m4a
    case wav
}

public struct PracticeRecordingArtifactKey: Equatable, Sendable {
    public var sessionID: String
    public var recordingID: String
    public var attemptNumber: Int
    public var targetTextHash: String
    public var targetLanguageCode: String
    public var recordingFormat: PracticeRecordingFormat
    public var createdAtBucket: String

    public init(
        sessionID: String,
        recordingID: String,
        attemptNumber: Int,
        targetTextHash: String,
        targetLanguageCode: String,
        recordingFormat: PracticeRecordingFormat,
        createdAtBucket: String
    ) {
        self.sessionID = sessionID
        self.recordingID = recordingID
        self.attemptNumber = attemptNumber
        self.targetTextHash = targetTextHash
        self.targetLanguageCode = targetLanguageCode
        self.recordingFormat = recordingFormat
        self.createdAtBucket = createdAtBucket
    }

    public var derivationKind: MediaArtifactDerivationKind {
        .practiceRecording
    }

    public var derivationKeyHash: String {
        Self.sha256Hex(for: canonicalRepresentation)
    }
}

public struct PracticeRecordingArtifactCommitInput: Sendable {
    public var key: PracticeRecordingArtifactKey
    public var languageSpaceID: String
    public var sessionID: String
    public var recordingID: String
    public var attemptNumber: Int
    public var stagedFile: MediaArtifactStagedFileReference
    public var mimeType: String
    public var durationSeconds: Double?
    public var sampleRate: Int?
    public var channelCount: Int?
    public var createdAt: Date

    public init(
        key: PracticeRecordingArtifactKey,
        languageSpaceID: String,
        sessionID: String,
        recordingID: String,
        attemptNumber: Int,
        stagedFile: MediaArtifactStagedFileReference,
        mimeType: String,
        durationSeconds: Double?,
        sampleRate: Int?,
        channelCount: Int?,
        createdAt: Date
    ) {
        self.key = key
        self.languageSpaceID = languageSpaceID
        self.sessionID = sessionID
        self.recordingID = recordingID
        self.attemptNumber = attemptNumber
        self.stagedFile = stagedFile
        self.mimeType = mimeType
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.createdAt = createdAt
    }
}

private extension PracticeRecordingArtifactKey {
    var canonicalRepresentation: String {
        [
            "attemptNumber=\(attemptNumber)",
            "createdAtBucket=\(createdAtBucket)",
            "recordingFormat=\(recordingFormat.rawValue)",
            "recordingID=\(recordingID)",
            "sessionID=\(sessionID)",
            "targetLanguageCode=\(targetLanguageCode)",
            "targetTextHash=\(targetTextHash)",
        ].joined(separator: "\n")
    }

    static func sha256Hex(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
