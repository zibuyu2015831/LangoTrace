import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Reading import preflight")
struct ReadingImportPreflightTests {
    @Test("empty pasted text is rejected before document creation")
    func emptyPastedTextIsRejected() {
        let result = ReadingImportPreflight.evaluatePastedText(
            "   ",
            limits: .verticalSliceDefaults
        )

        #expect(result.decision == .reject(.emptyContent))
    }

    @Test("long pasted text is accepted with long text warning below hard limit")
    func longPastedTextProducesWarning() {
        let text = String(repeating: "Language learning sentence. ", count: 700)

        let result = ReadingImportPreflight.evaluatePastedText(
            text,
            limits: .init(longTextCharacterThreshold: 10000, hardCharacterLimit: 50000, hardByteLimit: 200_000)
        )

        #expect(result.decision == .accept)
        #expect(result.warnings.contains(.longText))
        #expect(result.characterCount == text.count)
    }

    @Test("file metadata above hard byte limit is rejected before reading bytes")
    func hardByteLimitRejectsBeforeRead() {
        let result = ReadingImportPreflight.evaluateFileMetadata(
            filename: "book.txt",
            byteSize: 2_000_001,
            limits: .init(longTextCharacterThreshold: 10000, hardCharacterLimit: 50000, hardByteLimit: 2_000_000)
        )

        #expect(result.decision == .reject(.fileTooLarge))
        #expect(result.shouldReadFileBody == false)
    }

    @Test("txt and markdown files are supported while other extensions are rejected")
    func supportedExtensionsAreExplicit() {
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "note.txt", byteSize: 32, limits: .verticalSliceDefaults).decision == .accept)
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "article.md", byteSize: 32, limits: .verticalSliceDefaults).decision == .accept)
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "book.epub", byteSize: 32, limits: .verticalSliceDefaults).decision == .reject(.unsupportedFormat))
    }

    @Test("invalid text bytes fail as encoding failure")
    func invalidTextBytesFailAsEncodingFailure() {
        let invalid = Data([0xFF, 0xFE, 0x00, 0xD8])

        let result = ReadingImportPreflight.decodeTextData(
            invalid,
            filename: "broken.txt",
            limits: .verticalSliceDefaults
        )

        #expect(result.decision == .reject(.encodingFailed))
        #expect(result.text == nil)
    }
}
