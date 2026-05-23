import Foundation

public struct SentenceAudioKey: Equatable, Hashable, Sendable {
    public var sentenceSource: TTSSentenceSource
    public var sentenceTextHash: String
    public var targetLanguageCode: String
    public var configurationFingerprint: String

    public init(
        sentenceSource: TTSSentenceSource,
        sentenceTextHash: String,
        targetLanguageCode: String,
        configurationFingerprint: String
    ) {
        self.sentenceSource = sentenceSource
        self.sentenceTextHash = sentenceTextHash
        self.targetLanguageCode = targetLanguageCode
        self.configurationFingerprint = configurationFingerprint
    }
}

public struct SentenceAudioRequest: Equatable, Sendable {
    public var languageSpaceID: String
    public var owner: MediaArtifactOwner
    public var sentenceSource: TTSSentenceSource
    public var sentenceIndex: Int
    public var targetText: String
    public var targetLanguageCode: String

    public init(
        languageSpaceID: String,
        owner: MediaArtifactOwner,
        sentenceSource: TTSSentenceSource,
        sentenceIndex: Int,
        targetText: String,
        targetLanguageCode: String
    ) {
        self.languageSpaceID = languageSpaceID
        self.owner = owner
        self.sentenceSource = sentenceSource
        self.sentenceIndex = sentenceIndex
        self.targetText = targetText
        self.targetLanguageCode = targetLanguageCode
    }

    public var nonSensitiveSummary: SentenceAudioRequestSummary {
        SentenceAudioRequestSummary(
            languageSpaceID: languageSpaceID,
            sentenceIndex: sentenceIndex,
            targetLanguageCode: targetLanguageCode,
            textLengthBucket: .bucket(for: targetText)
        )
    }
}

public struct SentenceAudioRequestSummary: Equatable, Hashable, Sendable, CustomStringConvertible {
    public var languageSpaceID: String
    public var sentenceIndex: Int
    public var targetLanguageCode: String
    public var textLengthBucket: SentenceAudioTextLengthBucket

    public init(
        languageSpaceID: String,
        sentenceIndex: Int,
        targetLanguageCode: String,
        textLengthBucket: SentenceAudioTextLengthBucket
    ) {
        self.languageSpaceID = languageSpaceID
        self.sentenceIndex = sentenceIndex
        self.targetLanguageCode = targetLanguageCode
        self.textLengthBucket = textLengthBucket
    }

    public var description: String {
        "SentenceAudioRequestSummary(languageSpaceID: \(languageSpaceID), sentenceIndex: \(sentenceIndex), targetLanguageCode: \(targetLanguageCode), textLengthBucket: \(textLengthBucket.rawValue))"
    }
}

public enum SentenceAudioTextLengthBucket: String, CaseIterable, Codable, Sendable {
    case empty
    case short
    case medium
    case long

    public static func bucket(for text: String) -> SentenceAudioTextLengthBucket {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        switch count {
        case 0:
            return .empty
        case 1 ... 120:
            return .short
        case 121 ... 600:
            return .medium
        default:
            return .long
        }
    }
}

public enum SentenceAudioByteSizeBucket: String, CaseIterable, Codable, Sendable {
    case empty
    case small
    case medium
    case large
}

public enum SentenceAudioDurationBucket: String, CaseIterable, Codable, Sendable {
    case unknown
    case short
    case medium
    case long
}

public enum SentenceAudioCacheResult: String, CaseIterable, Codable, Sendable {
    case hit
    case miss
    case invalidated
}

public enum SentenceAudioConfigurationIssue: String, CaseIterable, Codable, Sendable {
    case notConfigured = "not_configured"
    case credentialMissing = "credential_missing"
    case notTested = "not_tested"
    case requiresRetest = "requires_retest"
    case failedLastTest = "failed_last_test"
    case unsupportedProvider = "unsupported_provider"

    public var isRecoverableConfigurationIssue: Bool {
        switch self {
        case .notConfigured, .credentialMissing, .notTested, .requiresRetest, .failedLastTest:
            true
        case .unsupportedProvider:
            false
        }
    }
}

public enum SentenceAudioPlaybackFailure: String, CaseIterable, Error, Codable, Sendable {
    case configurationUnavailable = "configuration_unavailable"
    case credentialMissing = "credential_missing"
    case notTested = "not_tested"
    case requiresRetest = "requires_retest"
    case failedLastTest = "failed_last_test"
    case unsupportedProvider = "unsupported_provider"
    case networkFailed = "network_failed"
    case authenticationFailed = "authentication_failed"
    case nonAudioResponse = "non_audio_response"
    case audioTooLarge = "audio_too_large"
    case mediaArtifactWriteFailed = "media_artifact_write_failed"
    case persistentFileValidationFailed = "persistent_file_validation_failed"
    case stagingWriteFailed = "staging_write_failed"
    case playbackSourceUnavailable = "playback_source_unavailable"
    case playbackFileUnavailable = "playback_file_unavailable"
    case audioEngineInitializationFailed = "audio_engine_initialization_failed"
    case playbackFailed = "playback_failed"
    case rateLimited = "rate_limited"
    case quotaExceeded = "quota_exceeded"
    case cancelled
}

public enum SentenceAudioPresentationState: Equatable, Sendable {
    case idle
    case generating(SentenceAudioKey)
    case playing(SentenceAudioKey)
    case paused(SentenceAudioKey)
    case requiresConfiguration(SentenceAudioConfigurationIssue)
    case failed(SentenceAudioPlaybackFailure)

    public var activeKey: SentenceAudioKey? {
        switch self {
        case let .generating(key), let .playing(key), let .paused(key):
            key
        case .idle, .requiresConfiguration, .failed:
            nil
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .failed:
            true
        case .idle, .generating, .playing, .paused, .requiresConfiguration:
            false
        }
    }

    public var isRecoverableConfigurationIssue: Bool {
        guard case let .requiresConfiguration(issue) = self else {
            return false
        }
        return issue.isRecoverableConfigurationIssue
    }
}

public enum SentenceAudioPlaybackTransition: Equatable, Sendable {
    case tap(SentenceAudioKey)
    case generationStarted(SentenceAudioKey)
    case generationSucceeded(SentenceAudioKey)
    case generationFailed(SentenceAudioKey, SentenceAudioPlaybackFailure)
    case playbackStarted(SentenceAudioKey)
    case playbackCompleted(SentenceAudioKey)
    case playbackFailed(SentenceAudioKey, SentenceAudioPlaybackFailure)
}

public enum SentenceAudioPlaybackEffect: Equatable, Sendable {
    case start(SentenceAudioKey)
    case cancelGeneration(SentenceAudioKey)
    case pause(SentenceAudioKey)
    case resume(SentenceAudioKey)
    case stopPlayback(SentenceAudioKey)
}

public struct SentenceAudioPlaybackCoordinatorState: Equatable, Sendable {
    public private(set) var activeKey: SentenceAudioKey?
    private var states: [SentenceAudioKey: SentenceAudioPresentationState]

    public init(activeKey: SentenceAudioKey? = nil) {
        self.activeKey = activeKey
        states = [:]
    }

    public func presentationState(for key: SentenceAudioKey) -> SentenceAudioPresentationState {
        states[key] ?? .idle
    }

    public mutating func setPresentationState(_ presentationState: SentenceAudioPresentationState, for key: SentenceAudioKey) {
        states[key] = presentationState
    }

    public mutating func reduce(_ transition: SentenceAudioPlaybackTransition) -> [SentenceAudioPlaybackEffect] {
        switch transition {
        case let .tap(key):
            return handleTap(key)
        case let .generationStarted(key):
            states[key] = .generating(key)
            activeKey = key
            return []
        case let .generationSucceeded(key):
            states[key] = .idle
            return []
        case let .generationFailed(key, failure):
            if activeKey == key {
                activeKey = nil
            }
            states[key] = .failed(failure)
            return []
        case let .playbackStarted(key):
            states[key] = .playing(key)
            activeKey = key
            return []
        case let .playbackCompleted(key):
            if activeKey == key {
                activeKey = nil
            }
            states[key] = .idle
            return []
        case let .playbackFailed(key, failure):
            if activeKey == key {
                activeKey = nil
            }
            states[key] = .failed(failure)
            return []
        }
    }

    private mutating func handleTap(_ key: SentenceAudioKey) -> [SentenceAudioPlaybackEffect] {
        switch presentationState(for: key) {
        case .generating:
            states[key] = .idle
            activeKey = nil
            return [.cancelGeneration(key)]
        case .playing:
            states[key] = .paused(key)
            return [.pause(key)]
        case .paused:
            states[key] = .playing(key)
            activeKey = key
            return [.resume(key)]
        case .idle, .requiresConfiguration, .failed:
            var effects: [SentenceAudioPlaybackEffect] = []
            if let activeKey, activeKey != key {
                switch presentationState(for: activeKey) {
                case .playing, .paused:
                    effects.append(.stopPlayback(activeKey))
                case .generating:
                    effects.append(.cancelGeneration(activeKey))
                case .idle, .requiresConfiguration, .failed:
                    break
                }
                states[activeKey] = .idle
            }
            activeKey = key
            states[key] = .idle
            effects.append(.start(key))
            return effects
        }
    }
}

public struct MediaArtifactPlaybackSource: Equatable, Sendable {
    public var artifactID: String
    public var fileURL: URL
    public var mimeType: String
    public var byteSize: Int64
    public var contentHash: String

    public init(
        artifactID: String,
        fileURL: URL,
        mimeType: String,
        byteSize: Int64,
        contentHash: String
    ) {
        self.artifactID = artifactID
        self.fileURL = fileURL
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.contentHash = contentHash
    }
}

public protocol MediaArtifactPlaybackSourceResolving: Sendable {
    func playbackSource(for artifact: MediaArtifact) async throws -> MediaArtifactPlaybackSource
}

public struct TTSAudioPlaybackSession: Sendable {
    private let completionResult: @Sendable () async -> Result<Void, SentenceAudioPlaybackFailure>

    public init(completionResult: @escaping @Sendable () async -> Result<Void, SentenceAudioPlaybackFailure>) {
        self.completionResult = completionResult
    }

    public func completion() async -> Result<Void, SentenceAudioPlaybackFailure> {
        await completionResult()
    }

    public static let completed = TTSAudioPlaybackSession {
        .success(())
    }
}

public protocol TTSAudioPlaying: Sendable {
    func play(_ source: MediaArtifactPlaybackSource) async throws -> TTSAudioPlaybackSession
    func pause() async
    func resume() async throws
    func stop() async
}
