import CryptoKit
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
    case contentEmpty
    case contentTooLong
    case operationInProgress
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
    public var materialID: String?
    public var analysisIsStale: Bool

    public init(
        category: LearningMaterialGenerationFailureCategory,
        operationID: DiagnosticOperationID? = nil,
        materialID: String? = nil,
        analysisIsStale: Bool = false
    ) {
        self.category = category
        self.operationID = operationID
        self.materialID = materialID
        self.analysisIsStale = analysisIsStale
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
        case let .failed(display):
            display.materialID
        case .idle, .generating, .blocked:
            nil
        }
    }

    public var analysisIsStale: Bool {
        switch self {
        case let .editing(_, analysisIsStale):
            analysisIsStale
        case let .failed(display):
            display.analysisIsStale
        case .idle, .generating, .generated, .analyzing, .cancelled, .blocked:
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
        if estimatedTokens <= 3000 {
            return .medium
        }
        return .tooLong
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400 ... 0x4DBF,
             0x4E00 ... 0x9FFF,
             0xF900 ... 0xFAFF,
             0x20000 ... 0x2A6DF,
             0x2A700 ... 0x2B73F,
             0x2B740 ... 0x2B81F,
             0x2B820 ... 0x2CEAF:
            true
        default:
            false
        }
    }

    private static func isLatinLetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII
    }
}

public struct NewLearningEntryDraft: Equatable, Sendable {
    public var title: String
    public var body: String
    public var source: EntrySource
    public var scene: String

    public init(title: String, body: String, source: EntrySource, scene: String) {
        self.title = title
        self.body = body
        self.source = source
        self.scene = scene
    }
}

public struct LearningMaterial: Equatable, Identifiable, Sendable {
    public var id: String
    public var entryID: String
    public var spaceID: String
    public var inputKind: LearningMaterialInputKind
    public var promptMode: LearningMaterialPromptMode
    public var learningText: String
    public var originalGeneratedText: String
    public var revisionSummary: [LearningRevision]
    public var analysis: LearningMaterialAnalysis
    public var metadata: LearningMaterialGenerationMetadata
    public var createdAt: Date
    public var updatedAt: Date
    public var isCurrent: Bool

    public init(
        id: String,
        entryID: String,
        spaceID: String,
        inputKind: LearningMaterialInputKind,
        promptMode: LearningMaterialPromptMode,
        learningText: String,
        originalGeneratedText: String,
        revisionSummary: [LearningRevision],
        analysis: LearningMaterialAnalysis,
        metadata: LearningMaterialGenerationMetadata,
        createdAt: Date,
        updatedAt: Date,
        isCurrent: Bool
    ) {
        self.id = id
        self.entryID = entryID
        self.spaceID = spaceID
        self.inputKind = inputKind
        self.promptMode = promptMode
        self.learningText = learningText
        self.originalGeneratedText = originalGeneratedText
        self.revisionSummary = revisionSummary
        self.analysis = analysis
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isCurrent = isCurrent
    }
}

public struct LearningRevision: Codable, Equatable, Identifiable, Sendable {
    public enum Category: String, Codable, CaseIterable, Equatable, Sendable {
        case grammar
        case wordChoice
        case naturalness
        case clarity
        case tone
        case structure
    }

    public var id: String
    public var originalText: String
    public var revisedText: String
    public var reasonNative: String
    public var category: Category
    public var position: Int

    public init(
        id: String,
        originalText: String,
        revisedText: String,
        reasonNative: String,
        category: Category,
        position: Int
    ) {
        self.id = id
        self.originalText = originalText
        self.revisedText = revisedText
        self.reasonNative = reasonNative
        self.category = category
        self.position = position
    }
}

public struct LearningMaterialAnalysis: Equatable, Sendable {
    public var status: LearningMaterialAnalysisStatus
    public var sourceTextHash: String
    public var sentences: [LearningSentenceAnalysis]
    public var memoryCandidates: [LearningMemoryCandidate]
    public var practiceCandidates: [LearningPracticeCandidate]

    public init(
        status: LearningMaterialAnalysisStatus,
        sourceTextHash: String,
        sentences: [LearningSentenceAnalysis],
        memoryCandidates: [LearningMemoryCandidate],
        practiceCandidates: [LearningPracticeCandidate]
    ) {
        self.status = status
        self.sourceTextHash = sourceTextHash
        self.sentences = sentences
        self.memoryCandidates = memoryCandidates
        self.practiceCandidates = practiceCandidates
    }
}

public struct LearningSentenceAnalysis: Equatable, Identifiable, Sendable {
    public var id: String
    public var nativeSentence: String
    public var targetSentence: String
    public var literalTranslation: String
    public var naturalTranslation: String
    public var grammarNotes: [String]
    public var keyPoints: [String]
    public var position: Int

    public init(
        id: String,
        nativeSentence: String,
        targetSentence: String,
        literalTranslation: String,
        naturalTranslation: String,
        grammarNotes: [String],
        keyPoints: [String],
        position: Int
    ) {
        self.id = id
        self.nativeSentence = nativeSentence
        self.targetSentence = targetSentence
        self.literalTranslation = literalTranslation
        self.naturalTranslation = naturalTranslation
        self.grammarNotes = grammarNotes
        self.keyPoints = keyPoints
        self.position = position
    }
}

public struct LearningMemoryCandidate: Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Equatable, Sendable {
        case word
        case phrase
        case sentencePattern
        case grammarPoint
        case errorPattern
    }

    public enum Difficulty: String, Codable, CaseIterable, Equatable, Sendable {
        case easy
        case medium
        case hard
    }

    public var id: String
    public var sentenceID: String?
    public var kind: Kind
    public var text: String
    public var explanationNative: String
    public var exampleTarget: String
    public var exampleNative: String
    public var difficulty: Difficulty

    public init(
        id: String,
        sentenceID: String?,
        kind: Kind,
        text: String,
        explanationNative: String,
        exampleTarget: String,
        exampleNative: String,
        difficulty: Difficulty
    ) {
        self.id = id
        self.sentenceID = sentenceID
        self.kind = kind
        self.text = text
        self.explanationNative = explanationNative
        self.exampleTarget = exampleTarget
        self.exampleNative = exampleNative
        self.difficulty = difficulty
    }
}

public struct LearningPracticeCandidate: Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Equatable, Sendable {
        case listening
        case shadowing
        case dictation
        case backTranslation
    }

    public var id: String
    public var sentenceID: String?
    public var kind: Kind
    public var title: String
    public var promptText: String
    public var answerText: String

    public init(
        id: String,
        sentenceID: String?,
        kind: Kind,
        title: String,
        promptText: String,
        answerText: String
    ) {
        self.id = id
        self.sentenceID = sentenceID
        self.kind = kind
        self.title = title
        self.promptText = promptText
        self.answerText = answerText
    }
}

public struct LearningMaterialGenerationMetadata: Equatable, Sendable {
    public var promptID: String
    public var promptVersion: String
    public var providerProfileID: String?
    public var providerEndpointID: String?
    public var providerPresetID: String
    public var modelName: String
    public var generatedAt: Date

    public init(
        promptID: String,
        promptVersion: String,
        providerProfileID: String?,
        providerEndpointID: String?,
        providerPresetID: String,
        modelName: String,
        generatedAt: Date
    ) {
        self.promptID = promptID
        self.promptVersion = promptVersion
        self.providerProfileID = providerProfileID
        self.providerEndpointID = providerEndpointID
        self.providerPresetID = providerPresetID
        self.modelName = modelName
        self.generatedAt = generatedAt
    }
}

public struct LearningMaterialGenerationResult: Equatable, Sendable {
    public var entryID: String
    public var spaceID: String
    public var inputKind: LearningMaterialInputKind
    public var promptMode: LearningMaterialPromptMode
    public var learningText: String
    public var revisionSummary: [LearningRevision]
    public var analysis: LearningMaterialAnalysis
    public var metadata: LearningMaterialGenerationMetadata

    public init(
        entryID: String,
        spaceID: String,
        inputKind: LearningMaterialInputKind,
        promptMode: LearningMaterialPromptMode,
        learningText: String,
        revisionSummary: [LearningRevision],
        analysis: LearningMaterialAnalysis,
        metadata: LearningMaterialGenerationMetadata
    ) {
        self.entryID = entryID
        self.spaceID = spaceID
        self.inputKind = inputKind
        self.promptMode = promptMode
        self.learningText = learningText
        self.revisionSummary = revisionSummary
        self.analysis = analysis
        self.metadata = metadata
    }
}

public struct LearningMaterialAnalysisResult: Equatable, Sendable {
    public var materialID: String
    public var analysis: LearningMaterialAnalysis

    public init(materialID: String, analysis: LearningMaterialAnalysis) {
        self.materialID = materialID
        self.analysis = analysis
    }
}

public struct LearningMaterialGenerationInput: Equatable, Sendable {
    public var entryID: String
    public var spaceID: String
    public var sourceText: String
    public var entrySource: EntrySource
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var proficiencyLevelCode: String
    public var promptMode: LearningMaterialPromptMode

    public init(
        entryID: String,
        spaceID: String,
        sourceText: String,
        entrySource: EntrySource,
        nativeLanguageCode: String,
        targetLanguageCode: String,
        proficiencyLevelCode: String,
        promptMode: LearningMaterialPromptMode
    ) {
        self.entryID = entryID
        self.spaceID = spaceID
        self.sourceText = sourceText
        self.entrySource = entrySource
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
        self.promptMode = promptMode
    }
}

public struct LearningMaterialAnalysisInput: Equatable, Sendable {
    public var materialID: String
    public var learningText: String
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var proficiencyLevelCode: String

    public init(
        materialID: String,
        learningText: String,
        nativeLanguageCode: String,
        targetLanguageCode: String,
        proficiencyLevelCode: String
    ) {
        self.materialID = materialID
        self.learningText = learningText
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
    }
}

public enum LearningMaterialOperationKind: String, Codable, CaseIterable, Equatable, Sendable {
    case generate
    case analyze
}

public enum LearningMaterialOperationStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case started
    case succeeded
    case failed
    case cancelled
}

public struct LearningMaterialOperationSummary: Equatable, Sendable {
    public var operationID: DiagnosticOperationID
    public var entryID: String
    public var materialID: String?
    public var kind: LearningMaterialOperationKind
    public var status: LearningMaterialOperationStatus
    public var failureCategory: LearningMaterialGenerationFailureCategory?
    public var promptID: String
    public var promptVersion: String
    public var providerProfileID: String?
    public var providerEndpointID: String?
    public var providerPresetID: String?
    public var modelName: String?
    public var inputKind: LearningMaterialInputKind?
    public var estimatedTokenBucket: LearningMaterialEstimatedTokenBucket
    public var durationMilliseconds: Int?
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        operationID: DiagnosticOperationID,
        entryID: String,
        materialID: String?,
        kind: LearningMaterialOperationKind,
        status: LearningMaterialOperationStatus,
        failureCategory: LearningMaterialGenerationFailureCategory?,
        promptID: String,
        promptVersion: String,
        providerProfileID: String?,
        providerEndpointID: String?,
        providerPresetID: String?,
        modelName: String?,
        inputKind: LearningMaterialInputKind?,
        estimatedTokenBucket: LearningMaterialEstimatedTokenBucket,
        durationMilliseconds: Int?,
        createdAt: Date,
        completedAt: Date?
    ) {
        self.operationID = operationID
        self.entryID = entryID
        self.materialID = materialID
        self.kind = kind
        self.status = status
        self.failureCategory = failureCategory
        self.promptID = promptID
        self.promptVersion = promptVersion
        self.providerProfileID = providerProfileID
        self.providerEndpointID = providerEndpointID
        self.providerPresetID = providerPresetID
        self.modelName = modelName
        self.inputKind = inputKind
        self.estimatedTokenBucket = estimatedTokenBucket
        self.durationMilliseconds = durationMilliseconds
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public static func started(
        operationID: DiagnosticOperationID,
        entryID: String,
        kind: LearningMaterialOperationKind,
        bucket: LearningMaterialEstimatedTokenBucket,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        promptID: String = "builtin.learning_material.generate.v1",
        promptVersion: String = "1"
    ) -> LearningMaterialOperationSummary {
        LearningMaterialOperationSummary(
            operationID: operationID,
            entryID: entryID,
            materialID: nil,
            kind: kind,
            status: .started,
            failureCategory: nil,
            promptID: promptID,
            promptVersion: promptVersion,
            providerProfileID: nil,
            providerEndpointID: nil,
            providerPresetID: nil,
            modelName: nil,
            inputKind: nil,
            estimatedTokenBucket: bucket,
            durationMilliseconds: nil,
            createdAt: createdAt,
            completedAt: nil
        )
    }

    public static func failed(
        operationID: DiagnosticOperationID,
        entryID: String,
        kind: LearningMaterialOperationKind,
        failureCategory: LearningMaterialGenerationFailureCategory,
        bucket: LearningMaterialEstimatedTokenBucket,
        completedAt: Date,
        promptID: String = "builtin.learning_material.generate.v1",
        promptVersion: String = "1"
    ) -> LearningMaterialOperationSummary {
        LearningMaterialOperationSummary(
            operationID: operationID,
            entryID: entryID,
            materialID: nil,
            kind: kind,
            status: .failed,
            failureCategory: failureCategory,
            promptID: promptID,
            promptVersion: promptVersion,
            providerProfileID: nil,
            providerEndpointID: nil,
            providerPresetID: nil,
            modelName: nil,
            inputKind: nil,
            estimatedTokenBucket: bucket,
            durationMilliseconds: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            completedAt: completedAt
        )
    }

    public static func cancelled(
        operationID: DiagnosticOperationID,
        entryID: String,
        materialID: String?,
        kind: LearningMaterialOperationKind,
        bucket: LearningMaterialEstimatedTokenBucket,
        completedAt: Date,
        promptID: String = "builtin.learning_material.generate.v1",
        promptVersion: String = "1"
    ) -> LearningMaterialOperationSummary {
        LearningMaterialOperationSummary(
            operationID: operationID,
            entryID: entryID,
            materialID: materialID,
            kind: kind,
            status: .cancelled,
            failureCategory: .cancelled,
            promptID: promptID,
            promptVersion: promptVersion,
            providerProfileID: nil,
            providerEndpointID: nil,
            providerPresetID: nil,
            modelName: nil,
            inputKind: nil,
            estimatedTokenBucket: bucket,
            durationMilliseconds: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            completedAt: completedAt
        )
    }
}

public enum LearningMaterialTextHash {
    public static func sha256(for text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
