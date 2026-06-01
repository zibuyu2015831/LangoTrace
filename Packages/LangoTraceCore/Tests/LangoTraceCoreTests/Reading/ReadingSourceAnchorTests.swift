import Testing
@testable import LangoTraceCore

@Suite("Reading source anchors")
struct ReadingSourceAnchorTests {
    @Test("anchor is current when revision structure block range and selected text hash match")
    func anchorCurrentWhenInputsMatch() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            structureVersion: 2,
            blockID: "block-1",
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a",
            characterOffset: 10,
            characterLength: 5
        )
        let state = anchor.resolve(
            currentRevision: 4,
            currentStructureVersion: 2,
            currentBlockID: "block-1",
            currentSelectedTextHash: "hash-a",
            currentCharacterOffset: 10,
            currentCharacterLength: 5
        )

        #expect(state == .current)
    }

    @Test("anchor is stale when revision changes")
    func anchorStaleWhenRevisionChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            structureVersion: 2,
            blockID: "block-1",
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a",
            characterOffset: 10,
            characterLength: 5
        )

        #expect(anchor.resolve(
            currentRevision: 5,
            currentStructureVersion: 2,
            currentBlockID: "block-1",
            currentSelectedTextHash: "hash-a",
            currentCharacterOffset: 10,
            currentCharacterLength: 5
        ) == .stale(.revisionChanged))
    }

    @Test("anchor is stale when structure version changes")
    func anchorStaleWhenStructureVersionChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            structureVersion: 2,
            blockID: "block-1",
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a",
            characterOffset: 10,
            characterLength: 5
        )

        #expect(anchor.resolve(
            currentRevision: 4,
            currentStructureVersion: 3,
            currentBlockID: "block-1",
            currentSelectedTextHash: "hash-a",
            currentCharacterOffset: 10,
            currentCharacterLength: 5
        ) == .stale(.structureChanged))
    }

    @Test("anchor is stale when selected text hash changes")
    func anchorStaleWhenHashChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            structureVersion: 2,
            blockID: "block-1",
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a",
            characterOffset: 10,
            characterLength: 5
        )

        #expect(anchor.resolve(
            currentRevision: 4,
            currentStructureVersion: 2,
            currentBlockID: "block-1",
            currentSelectedTextHash: "hash-b",
            currentCharacterOffset: 10,
            currentCharacterLength: 5
        ) == .stale(.selectedTextChanged))
    }

    @Test("anchor is stale when block or range changes")
    func anchorStaleWhenBlockOrRangeChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            structureVersion: 2,
            blockID: "block-1",
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a",
            characterOffset: 10,
            characterLength: 5
        )

        #expect(anchor.resolve(
            currentRevision: 4,
            currentStructureVersion: 2,
            currentBlockID: "block-2",
            currentSelectedTextHash: "hash-a",
            currentCharacterOffset: 10,
            currentCharacterLength: 5
        ) == .stale(.blockChanged))

        #expect(anchor.resolve(
            currentRevision: 4,
            currentStructureVersion: 2,
            currentBlockID: "block-1",
            currentSelectedTextHash: "hash-a",
            currentCharacterOffset: 11,
            currentCharacterLength: 5
        ) == .stale(.rangeChanged))
    }
}
