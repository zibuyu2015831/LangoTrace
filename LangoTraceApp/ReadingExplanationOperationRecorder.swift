import Foundation
import LangoTraceAI
import LangoTraceData

enum ReadingExplanationOperationStatus {
    case pending
    case succeeded
    case cancelled
    case failed(category: String)

    var persistedValue: String {
        switch self {
        case .pending: "pending"
        case .succeeded: "succeeded"
        case .cancelled: "cancelled"
        case .failed: "failed"
        }
    }

    var persistedFailureCategory: String? {
        switch self {
        case .failed(let category): category
        default: nil
        }
    }
}

// Single point that maps ReadingExplanationOperationStatus to the repository record.
struct ReadingExplanationOperationRecorder {
    private let repository: GRDBReadingLibraryRepository
    private var base: ReadingAIExplanationOperationRecord

    init(repository: GRDBReadingLibraryRepository, base: ReadingAIExplanationOperationRecord) {
        self.repository = repository
        self.base = base
    }

    func record(_ status: ReadingExplanationOperationStatus,
                profile: AIProviderConfigurationProfile? = nil,
                endpoint: AIProviderEndpointInput? = nil) {
        var record = base
        record.providerProfileID = profile?.id ?? base.providerProfileID
        record.providerEndpointID = endpoint?.id ?? base.providerEndpointID
        record.providerPresetID = endpoint?.providerPresetID ?? base.providerPresetID
        record.modelName = endpoint?.modelName ?? base.modelName
        record.status = status.persistedValue
        record.failureCategory = status.persistedFailureCategory
        record.completedAt = status == .pending ? nil : Date()
        try? repository.recordAIExplanationOperation(record)
    }
}

// ReadingExplanationOperationStatus needs Equatable for .pending nil check
extension ReadingExplanationOperationStatus: Equatable {
    static func == (lhs: ReadingExplanationOperationStatus, rhs: ReadingExplanationOperationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.succeeded, .succeeded), (.cancelled, .cancelled):
            true
        case let (.failed(l), .failed(r)):
            l == r
        default:
            false
        }
    }
}
