public struct ReadingSourceAnchor: Equatable, Sendable {
    public var documentID: String
    public var sourceRevision: Int
    public var structureVersion: Int
    public var blockID: String
    public var sentenceID: String?
    public var selectedTextHash: String
    public var characterOffset: Int
    public var characterLength: Int

    public init(
        documentID: String,
        sourceRevision: Int,
        structureVersion: Int,
        blockID: String,
        sentenceID: String?,
        selectedTextHash: String,
        characterOffset: Int,
        characterLength: Int
    ) {
        self.documentID = documentID
        self.sourceRevision = sourceRevision
        self.structureVersion = structureVersion
        self.blockID = blockID
        self.sentenceID = sentenceID
        self.selectedTextHash = selectedTextHash
        self.characterOffset = characterOffset
        self.characterLength = characterLength
    }

    public func resolve(
        currentRevision: Int,
        currentStructureVersion: Int,
        currentBlockID: String,
        currentSelectedTextHash: String,
        currentCharacterOffset: Int,
        currentCharacterLength: Int
    ) -> ReadingSourceAnchorResolution {
        if currentRevision != sourceRevision {
            return .stale(.revisionChanged)
        }
        if currentStructureVersion != structureVersion {
            return .stale(.structureChanged)
        }
        if currentBlockID != blockID {
            return .stale(.blockChanged)
        }
        if currentSelectedTextHash != selectedTextHash {
            return .stale(.selectedTextChanged)
        }
        if currentCharacterOffset != characterOffset || currentCharacterLength != characterLength {
            return .stale(.rangeChanged)
        }
        return .current
    }
}

public enum ReadingSourceAnchorResolution: Equatable, Sendable {
    case current
    case stale(ReadingSourceAnchorStaleReason)
}

public enum ReadingSourceAnchorStaleReason: Equatable, Sendable {
    case revisionChanged
    case structureChanged
    case blockChanged
    case selectedTextChanged
    case rangeChanged
}
