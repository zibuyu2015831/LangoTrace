import Foundation

public struct ReadingImportPreflightLimits: Equatable, Sendable {
    public var longTextCharacterThreshold: Int
    public var hardCharacterLimit: Int
    public var hardByteLimit: Int

    public init(longTextCharacterThreshold: Int, hardCharacterLimit: Int, hardByteLimit: Int) {
        self.longTextCharacterThreshold = longTextCharacterThreshold
        self.hardCharacterLimit = hardCharacterLimit
        self.hardByteLimit = hardByteLimit
    }

    public static let verticalSliceDefaults = ReadingImportPreflightLimits(
        longTextCharacterThreshold: 10000,
        hardCharacterLimit: 50000,
        hardByteLimit: 2_000_000
    )
}

public enum ReadingImportPreflightFailure: Equatable, Sendable {
    case emptyContent
    case fileTooLarge
    case textTooLarge
    case unsupportedFormat
    case encodingFailed
}

public enum ReadingImportPreflightWarning: Equatable, Sendable {
    case longText
}

public enum ReadingImportPreflightDecision: Equatable, Sendable {
    case accept
    case reject(ReadingImportPreflightFailure)
}

public struct ReadingImportPreflightResult: Equatable, Sendable {
    public var decision: ReadingImportPreflightDecision
    public var warnings: Set<ReadingImportPreflightWarning>
    public var characterCount: Int
    public var byteSize: Int?
    public var shouldReadFileBody: Bool
    public var text: String?

    public init(
        decision: ReadingImportPreflightDecision,
        warnings: Set<ReadingImportPreflightWarning> = [],
        characterCount: Int = 0,
        byteSize: Int? = nil,
        shouldReadFileBody: Bool = false,
        text: String? = nil
    ) {
        self.decision = decision
        self.warnings = warnings
        self.characterCount = characterCount
        self.byteSize = byteSize
        self.shouldReadFileBody = shouldReadFileBody
        self.text = text
    }
}

public enum ReadingImportPreflight {
    public static func evaluatePastedText(
        _ text: String,
        limits: ReadingImportPreflightLimits
    ) -> ReadingImportPreflightResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ReadingImportPreflightResult(decision: .reject(.emptyContent))
        }
        guard text.count <= limits.hardCharacterLimit else {
            return ReadingImportPreflightResult(
                decision: .reject(.textTooLarge),
                characterCount: text.count,
                text: text
            )
        }

        var warnings: Set<ReadingImportPreflightWarning> = []
        if text.count >= limits.longTextCharacterThreshold {
            warnings.insert(.longText)
        }
        return ReadingImportPreflightResult(
            decision: .accept,
            warnings: warnings,
            characterCount: text.count,
            text: text
        )
    }

    public static func evaluateFileMetadata(
        filename: String,
        byteSize: Int,
        limits: ReadingImportPreflightLimits
    ) -> ReadingImportPreflightResult {
        guard isSupportedFileExtension(filename) else {
            return ReadingImportPreflightResult(
                decision: .reject(.unsupportedFormat),
                byteSize: byteSize,
                shouldReadFileBody: false
            )
        }
        guard byteSize <= limits.hardByteLimit else {
            return ReadingImportPreflightResult(
                decision: .reject(.fileTooLarge),
                byteSize: byteSize,
                shouldReadFileBody: false
            )
        }
        return ReadingImportPreflightResult(
            decision: .accept,
            byteSize: byteSize,
            shouldReadFileBody: true
        )
    }

    public static func decodeTextData(
        _ data: Data,
        filename: String,
        limits: ReadingImportPreflightLimits
    ) -> ReadingImportPreflightResult {
        let metadata = evaluateFileMetadata(filename: filename, byteSize: data.count, limits: limits)
        guard metadata.decision == .accept else {
            return metadata
        }

        let decoded = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .utf16LittleEndian)
            ?? String(data: data, encoding: .utf16BigEndian)

        guard let text = decoded, isValidDecodedText(text) else {
            return ReadingImportPreflightResult(
                decision: .reject(.encodingFailed),
                byteSize: data.count,
                shouldReadFileBody: true
            )
        }

        var result = evaluatePastedText(text, limits: limits)
        result.byteSize = data.count
        result.shouldReadFileBody = true
        return result
    }

    private static func isSupportedFileExtension(_ filename: String) -> Bool {
        let ext = filename.split(separator: ".").last.map { String($0).lowercased() }
        return ext == "txt" || ext == "md"
    }

    private static func isValidDecodedText(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value == 0xFFFD || scalar.value == 0xFFFE || scalar.value == 0xFFFF {
                return false
            }
        }
        return true
    }
}
