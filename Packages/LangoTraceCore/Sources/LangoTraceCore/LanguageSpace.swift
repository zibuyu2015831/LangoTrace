import Foundation

public struct LanguageSpace: Equatable, Sendable, Identifiable {
    public let id: String
    public let nativeLanguageCode: String
    public let targetLanguageCode: String
    public let level: LanguageLevel
    public let displayName: String
    public let displayNameNormalized: String
    public let createdAt: Date
    public let updatedAt: Date
    public let lastOpenedAt: Date?
    public let deletedAt: Date?

    public init(
        id: String,
        nativeLanguageCode: String,
        targetLanguageCode: String,
        level: LanguageLevel,
        displayName: String,
        displayNameNormalized: String,
        createdAt: Date,
        updatedAt: Date,
        lastOpenedAt: Date?,
        deletedAt: Date?
    ) {
        self.id = id
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.level = level
        self.displayName = displayName
        self.displayNameNormalized = displayNameNormalized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.deletedAt = deletedAt
    }

    public var isActive: Bool {
        deletedAt == nil
    }

    public var preview: LanguageSpacePreview {
        LanguageSpacePreview(
            id: id,
            name: displayName,
            nativeLanguage: LearningLanguage.find(code: nativeLanguageCode)?.zhHansName ?? nativeLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            targetLanguage: LearningLanguage.find(code: targetLanguageCode)?.zhHansName ?? targetLanguageCode,
            targetLanguageCode: targetLanguageCode,
            level: level
        )
    }

    public var activePreview: LanguageSpacePreview? {
        isActive ? preview : nil
    }
}

public struct CreateLanguageSpaceInput: Equatable, Sendable {
    public let nativeLanguageCode: String
    public let targetLanguageCode: String
    public let level: LanguageLevel
    public let displayName: String

    public init(
        nativeLanguageCode: String,
        targetLanguageCode: String,
        level: LanguageLevel,
        displayName: String
    ) {
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.level = level
        self.displayName = displayName
    }

    public func normalized() throws -> NormalizedLanguageSpaceInput {
        let draft = OnboardingDraft(
            nativeLanguageCode: nativeLanguageCode,
            targetLanguageCode: targetLanguageCode,
            level: level
        ).normalized()
        let targetLanguage = draft.resolvedTargetLanguage
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = trimmedDisplayName.isEmpty ? targetLanguage.defaultSpaceName : trimmedDisplayName
        return NormalizedLanguageSpaceInput(
            nativeLanguageCode: draft.nativeLanguageCode,
            targetLanguageCode: draft.targetLanguageCode,
            level: draft.level,
            displayName: resolvedDisplayName,
            displayNameNormalized: Self.normalizedDisplayName(resolvedDisplayName)
        )
    }

    public static func normalizedDisplayName(_ displayName: String) -> String {
        let nfc = displayName.precomposedStringWithCanonicalMapping
        let trimmed = nfc.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.unicodeScalars.map { scalar in
            guard (65 ... 90).contains(Int(scalar.value)),
                  let lowercased = UnicodeScalar(scalar.value + 32)
            else {
                return Character(scalar)
            }
            return Character(lowercased)
        })
    }
}

public struct UpdateLanguageSpaceInput: Equatable, Sendable {
    public let nativeLanguageCode: String
    public let targetLanguageCode: String
    public let level: LanguageLevel
    public let displayName: String

    public init(
        nativeLanguageCode: String,
        targetLanguageCode: String,
        level: LanguageLevel,
        displayName: String
    ) {
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.level = level
        self.displayName = displayName
    }

    public func normalized() throws -> NormalizedLanguageSpaceInput {
        try CreateLanguageSpaceInput(
            nativeLanguageCode: nativeLanguageCode,
            targetLanguageCode: targetLanguageCode,
            level: level,
            displayName: displayName
        ).normalized()
    }
}

public struct NormalizedLanguageSpaceInput: Equatable, Sendable {
    public let nativeLanguageCode: String
    public let targetLanguageCode: String
    public let level: LanguageLevel
    public let displayName: String
    public let displayNameNormalized: String
}

public enum LanguageSpaceError: Error, Equatable, Sendable {
    case storageUnavailable
    case migrationFailed
    case notFound
    case deleted
    case invalidInput
    case noActiveLanguageSpace
}

public struct LanguageSpaceDeletionResult: Equatable, Sendable {
    public let deletedSpaceID: String
    public let fallbackCurrentSpace: LanguageSpace?
    public let remainingActiveCount: Int

    public init(
        deletedSpaceID: String,
        fallbackCurrentSpace: LanguageSpace?,
        remainingActiveCount: Int
    ) {
        self.deletedSpaceID = deletedSpaceID
        self.fallbackCurrentSpace = fallbackCurrentSpace
        self.remainingActiveCount = remainingActiveCount
    }
}
