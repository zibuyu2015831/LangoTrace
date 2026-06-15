import Foundation
import LangoTraceCore

public struct LearningEntry: Equatable, Identifiable, Sendable {
    public let id: String
    public let spaceID: String
    public var title: String
    public var body: String
    public var source: EntrySource
    public var scene: String
    public var createdAt: Date
    public var updatedAt: Date
    public var practiceSummary: String

    public init(
        id: String,
        spaceID: String,
        title: String,
        body: String,
        source: EntrySource,
        scene: String,
        createdAt: Date,
        updatedAt: Date? = nil,
        practiceSummary: String = "待练习"
    ) {
        self.id = id
        self.spaceID = spaceID
        self.title = title
        self.body = body
        self.source = source
        self.scene = scene
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.practiceSummary = practiceSummary
    }

    public var sourceTitle: String {
        source.rawValue
    }
}

public struct RenderingSentence: Equatable, Identifiable, Sendable {
    public let id: String
    public let translation: String
    public let targetText: String
    public let note: String

    public init(id: String, translation: String, targetText: String, note: String) {
        self.id = id
        self.translation = translation
        self.targetText = targetText
        self.note = note
    }
}

public struct LearningRendering: Equatable, Identifiable, Sendable {
    public let id: String
    public let entryID: String
    public let targetText: String
    public let promptLabel: String
    public let providerLabel: String
    public let isMock: Bool
    public let sourceEntryBodyHash: String
    public let sentences: [RenderingSentence]

    public init(
        id: String,
        entryID: String,
        targetText: String,
        promptLabel: String,
        providerLabel: String,
        isMock: Bool,
        sourceEntryBodyHash: String,
        sentences: [RenderingSentence]
    ) {
        self.id = id
        self.entryID = entryID
        self.targetText = targetText
        self.promptLabel = promptLabel
        self.providerLabel = providerLabel
        self.isMock = isMock
        self.sourceEntryBodyHash = sourceEntryBodyHash
        self.sentences = sentences
    }
}

public struct PracticeItem: Equatable, Identifiable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case listening
        case shadowing
        case dictation
        case backTranslation
    }

    public let id: String
    public let entryID: String
    public let title: String
    public let kind: Kind
    public let summary: String

    public init(id: String, entryID: String, title: String, kind: Kind, summary: String) {
        self.id = id
        self.entryID = entryID
        self.title = title
        self.kind = kind
        self.summary = summary
    }
}

public struct MemoryItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let spaceID: String
    public let entryID: String
    public let text: String
    public let note: String

    public init(id: String, spaceID: String, entryID: String, text: String, note: String) {
        self.id = id
        self.spaceID = spaceID
        self.entryID = entryID
        self.text = text
        self.note = note
    }
}
