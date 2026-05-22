import Foundation

public enum EntrySource: String, Codable, CaseIterable, Equatable, Sendable {
    case typedText
    case photoWriting
    case targetLanguageWriting
}

public enum LearningMaterialInputKind: String, Codable, CaseIterable, Equatable, Sendable {
    case nativeRecord
    case targetWriting
    case mixed
    case uncertain

    public static func kind(inferredFrom _: EntrySource) -> LearningMaterialInputKind? {
        nil
    }
}

public enum LearningMaterialPromptMode: String, Codable, CaseIterable, Equatable, Sendable {
    case automaticLearningMaterial
    case analyzeCurrentLearningText
}

public enum LearningMaterialAnalysisStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case fresh
    case stale
    case missing
    case failed
}

public enum LearningMaterialGenerationFailureCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case providerNotConfigured
    case credentialMissing
    case networkUnavailable
    case timeout
    case providerRejected
    case unsupportedProvider
    case unsupportedModel
    case contentTooLong
    case invalidStructuredResponse
    case cancelled
    case persistenceFailed
    case unknown
}

public enum LearningMaterialEstimatedTokenBucket: String, Codable, CaseIterable, Equatable, Sendable {
    case short
    case medium
    case tooLong
}

public enum LearningMaterialGenerationBlockReason: String, Codable, CaseIterable, Equatable, Sendable {
    case providerNotConfigured
    case credentialMissing
    case contentEmpty
    case contentTooLong
    case operationInProgress
}

public struct LearningMaterialGenerationFailureDisplay: Equatable, Sendable {
    public var category: LearningMaterialGenerationFailureCategory
    public var operationID: DiagnosticOperationID?

    public init(
        category: LearningMaterialGenerationFailureCategory,
        operationID: DiagnosticOperationID? = nil
    ) {
        self.category = category
        self.operationID = operationID
    }
}

public enum LearningMaterialGenerationState: Equatable, Sendable {
    case idle
    case generating(operationID: DiagnosticOperationID)
    case generated(materialID: String)
    case editing(materialID: String, analysisIsStale: Bool)
    case analyzing(materialID: String, operationID: DiagnosticOperationID)
    case failed(LearningMaterialGenerationFailureDisplay)
    case cancelled(materialID: String?)
    case blocked(LearningMaterialGenerationBlockReason)

    public var isRunning: Bool {
        switch self {
        case .generating, .analyzing:
            true
        case .idle, .generated, .editing, .failed, .cancelled, .blocked:
            false
        }
    }

    public var canStartGeneration: Bool {
        !isRunning
    }

    public var operationID: DiagnosticOperationID? {
        switch self {
        case let .generating(operationID), let .analyzing(_, operationID):
            operationID
        case let .failed(display):
            display.operationID
        case .idle, .generated, .editing, .cancelled, .blocked:
            nil
        }
    }

    public var materialID: String? {
        switch self {
        case let .generated(materialID),
             let .editing(materialID, _),
             let .analyzing(materialID, _):
            materialID
        case let .cancelled(materialID):
            materialID
        case .idle, .generating, .failed, .blocked:
            nil
        }
    }

    public var analysisIsStale: Bool {
        switch self {
        case let .editing(_, analysisIsStale):
            analysisIsStale
        case .idle, .generating, .generated, .analyzing, .failed, .cancelled, .blocked:
            false
        }
    }
}

public enum LearningMaterialLengthEstimator {
    public static func estimateTokens(for text: String) -> Int {
        var cjkCount = 0
        var latinWordCount = 0
        var otherScalarCount = 0
        var isInsideLatinWord = false

        for scalar in text.unicodeScalars {
            if isCJK(scalar) {
                cjkCount += 1
                isInsideLatinWord = false
            } else if isLatinLetterOrDigit(scalar) {
                if !isInsideLatinWord {
                    latinWordCount += 1
                    isInsideLatinWord = true
                }
            } else {
                isInsideLatinWord = false
                if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    otherScalarCount += 1
                }
            }
        }

        let estimated = Double(cjkCount) + (Double(latinWordCount) * 1.3) + (Double(otherScalarCount) / 4.0)
        return Int(ceil(estimated))
    }

    public static func bucket(for text: String) -> LearningMaterialEstimatedTokenBucket {
        let estimatedTokens = estimateTokens(for: text)
        if estimatedTokens <= 800 {
            return .short
        }
        if estimatedTokens <= 3_000 {
            return .medium
        }
        return .tooLong
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF:
            true
        default:
            false
        }
    }

    private static func isLatinLetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII
    }
}
