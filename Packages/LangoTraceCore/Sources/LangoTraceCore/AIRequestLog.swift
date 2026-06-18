import Foundation

/// Outcome status recorded for an outbound AI request. `cancelled` is a
/// first-class status (a user-cancelled request is a fact users care about for
/// transparency), distinct from a failure (`docs/spec/005` §4.7 — cancel is not
/// a failure).
public enum AIRequestLogStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case success
    case failed
    case cancelled
}

/// Closed, non-sensitive failure bucket the per-domain service failure
/// categories collapse into for the request log.
///
/// E0a enriched (did not unify) the per-domain failure enums, so this mapping
/// table is the *standing* design, not a transitional shim: every domain
/// `FailureCategory` maps here through an explicit, total `init`.
public enum AIRequestLogFailureBucket: String, Codable, CaseIterable, Equatable, Sendable {
    case providerNotConfigured
    case credentialMissing
    case network
    case timeout
    case providerRejected
    case unsupported
    case invalidResponse
    case persistence
    case unknown

    public init(_ category: LearningMaterialGenerationFailureCategory) {
        switch category {
        case .providerNotConfigured:
            self = .providerNotConfigured
        case .credentialMissing, .authenticationFailed:
            self = .credentialMissing
        case .networkUnavailable:
            self = .network
        case .timeout:
            self = .timeout
        case .rateLimited, .providerRejected:
            self = .providerRejected
        case .unsupportedProvider, .unsupportedModel:
            self = .unsupported
        case .invalidStructuredResponse:
            self = .invalidResponse
        case .persistenceFailed:
            self = .persistence
        case .contentEmpty, .contentTooLong, .operationInProgress, .cancelled, .unknown:
            // Pre-flight block reasons / cancel never reach a failed log row
            // (they block before send or are recorded as `.cancelled` status);
            // map defensively so the initializer stays total.
            self = .unknown
        }
    }

    public init(_ category: ReadingSelectionExplanationFailureCategory) {
        switch category {
        case .providerNotConfigured:
            self = .providerNotConfigured
        case .authenticationFailed:
            self = .credentialMissing
        case .networkUnavailable:
            self = .network
        case .timeout:
            self = .timeout
        case .rateLimited, .providerRejected:
            self = .providerRejected
        case .unsupportedProvider, .unsupportedModel:
            self = .unsupported
        case .invalidStructuredResponse:
            self = .invalidResponse
        case .cancelled:
            self = .unknown
        }
    }

    public init(_ category: PracticeBacktranslationReviewFailureCategory) {
        switch category {
        case .providerNotConfigured:
            self = .providerNotConfigured
        case .authenticationFailed:
            self = .credentialMissing
        case .networkUnavailable:
            self = .network
        case .timeout:
            self = .timeout
        case .rateLimited, .providerRejected:
            self = .providerRejected
        case .unsupportedProvider, .unsupportedModel:
            self = .unsupported
        case .invalidStructuredResponse:
            self = .invalidResponse
        case .cancelled:
            self = .unknown
        }
    }
}

/// The outcome of an attempted outbound AI request, used to stamp a log row.
/// `cancelled` carries no failure bucket; `failed` always does.
public enum AIRequestLogOutcome: Equatable, Sendable {
    case success
    case cancelled
    case failed(AIRequestLogFailureBucket)

    public var status: AIRequestLogStatus {
        switch self {
        case .success: .success
        case .cancelled: .cancelled
        case .failed: .failed
        }
    }

    public var failureBucket: AIRequestLogFailureBucket? {
        switch self {
        case .success, .cancelled: nil
        case let .failed(bucket): bucket
        }
    }
}

/// A single non-sensitive request log row.
///
/// The model layer *structurally* cannot hold user content: there is no
/// free-text field for original text, selection, rendered prompt, request body
/// or credential. It records only the allowlisted attributes (mirroring the
/// `DiagnosticAttribute` closed-enum allowlist pattern). `ai_request_logs` is
/// local diagnostic data — not synced, not exported (`docs/spec/005` §4.4).
public struct AIRequestLogEntry: Equatable, Identifiable, Sendable {
    public var id: String
    public var operationID: DiagnosticOperationID
    public var capability: AIRequestCapability
    public var providerPresetID: String?
    public var endpointPurpose: AIProviderEndpointPurpose?
    public var adapterKind: AIProviderAdapterKind?
    public var modelName: String?
    public var promptID: String?
    public var promptVersion: String?
    public var inputLengthBucket: AIRequestLengthBucket
    public var status: AIRequestLogStatus
    public var failureBucket: AIRequestLogFailureBucket?
    public var createdAt: Date

    public init(
        id: String,
        operationID: DiagnosticOperationID,
        capability: AIRequestCapability,
        providerPresetID: String?,
        endpointPurpose: AIProviderEndpointPurpose?,
        adapterKind: AIProviderAdapterKind?,
        modelName: String?,
        promptID: String?,
        promptVersion: String?,
        inputLengthBucket: AIRequestLengthBucket,
        status: AIRequestLogStatus,
        failureBucket: AIRequestLogFailureBucket?,
        createdAt: Date
    ) {
        self.id = id
        self.operationID = operationID
        self.capability = capability
        self.providerPresetID = providerPresetID
        self.endpointPurpose = endpointPurpose
        self.adapterKind = adapterKind
        self.modelName = modelName
        self.promptID = promptID
        self.promptVersion = promptVersion
        self.inputLengthBucket = inputLengthBucket
        self.status = status
        self.failureBucket = failureBucket
        self.createdAt = createdAt
    }
}

/// Persistence boundary for the local request log. Writes prune older rows per
/// capability so the log stays bounded; reads are newest-first.
public protocol AIRequestLogRepository: Sendable {
    /// Appends a row and prunes the capability's history to the retention cap in
    /// the same transaction.
    func append(_ entry: AIRequestLogEntry) async throws
    /// Most recent rows for a single capability, newest first.
    func recent(capability: AIRequestCapability, limit: Int) async throws -> [AIRequestLogEntry]
    /// Most recent rows across all capabilities, newest first.
    func recentAll(limit: Int) async throws -> [AIRequestLogEntry]
}
