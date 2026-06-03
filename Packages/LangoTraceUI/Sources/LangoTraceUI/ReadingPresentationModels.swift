import LangoTraceCore

public enum ReadingPlatformRole: Equatable, Sendable {
    case phone
    case pad
    case mac
}

public enum ReadingInspectorPresentation: Equatable, Sendable {
    case inlineBottomPanel
    case sidePanel
}

public enum ReadingCompactLearningPanelState: Equatable, Sendable {
    case hidden
    case collapsed
    case loading
    case content
    case failed
}

public enum ReadingWorkbenchStyle: Equatable, Sendable {
    case focusedCanvas
    case balancedWorkbench
}

public struct ReadingLayoutModel: Equatable, Sendable {
    public var platform: ReadingPlatformRole
    public var primaryColumnCount: Int
    public var inspectorPresentation: ReadingInspectorPresentation
    public var workspaceStyle: ReadingWorkbenchStyle
    public var showsPersistentInspector: Bool

    public static func platform(_ platform: ReadingPlatformRole) -> ReadingLayoutModel {
        switch platform {
        case .phone:
            ReadingLayoutModel(
                platform: platform,
                primaryColumnCount: 1,
                inspectorPresentation: .inlineBottomPanel,
                workspaceStyle: .focusedCanvas,
                showsPersistentInspector: false
            )
        case .pad:
            ReadingLayoutModel(
                platform: platform,
                primaryColumnCount: 2,
                inspectorPresentation: .sidePanel,
                workspaceStyle: .focusedCanvas,
                showsPersistentInspector: true
            )
        case .mac:
            ReadingLayoutModel(
                platform: platform,
                primaryColumnCount: 3,
                inspectorPresentation: .sidePanel,
                workspaceStyle: .balancedWorkbench,
                showsPersistentInspector: true
            )
        }
    }
}

public struct ReadingChunkPresentation: Equatable, Sendable {
    public var id: String
    public var text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct ReadingPresentationState: Equatable, Sendable {
    public var layout: ReadingLayoutModel
    public var chunks: [ReadingChunkPresentation]
    public var selectedText: String?
    public var selectedChunkID: String?
    public var isInspectorPresented: Bool

    public init(
        layout: ReadingLayoutModel,
        chunks: [ReadingChunkPresentation],
        selectedText: String? = nil,
        selectedChunkID: String? = nil,
        isInspectorPresented: Bool = false
    ) {
        self.layout = layout
        self.chunks = chunks
        self.selectedText = selectedText
        self.selectedChunkID = selectedChunkID
        self.isInspectorPresented = isInspectorPresented
    }

    public mutating func selectText(_ text: String, inChunkID chunkID: String) {
        selectedText = text
        selectedChunkID = chunkID
        isInspectorPresented = true
    }
}

public enum ReadingPhoneDestination: Equatable, Sendable {
    case libraryHome
    case documentDetail(documentID: String)
}

public struct ReadingPhoneNavigationState: Equatable, Sendable {
    public var destination: ReadingPhoneDestination

    public init(destination: ReadingPhoneDestination = .libraryHome) {
        self.destination = destination
    }

    public var showsLibraryChrome: Bool {
        destination == .libraryHome
    }

    public var showsDocumentDetail: Bool {
        if case .documentDetail = destination {
            return true
        }
        return false
    }

    public mutating func openDocument(id: String) {
        destination = .documentDetail(documentID: id)
    }

    public mutating func closeDetail() {
        destination = .libraryHome
    }
}

public struct ReadingDetailChromeModel: Equatable, Sendable {
    public var showsToolbarEditAction: Bool
    public var showsInlineMetadataHeader: Bool

    public init(showsToolbarEditAction: Bool, showsInlineMetadataHeader: Bool) {
        self.showsToolbarEditAction = showsToolbarEditAction
        self.showsInlineMetadataHeader = showsInlineMetadataHeader
    }

    public static let phoneReading = ReadingDetailChromeModel(
        showsToolbarEditAction: true,
        showsInlineMetadataHeader: false
    )
}

public struct ReadingDocumentPresentation: Equatable, Sendable {
    public var blocks: [ReadingBlockPresentation]
    public var style: ReadingPresentationStyle

    public var inlineRuns: [ReadingInlinePresentation] {
        blocks.flatMap(\.inlineRuns)
    }
}

public struct ReadingBlockPresentation: Equatable, Sendable {
    public var id: String
    public var kind: ReadingMarkdownBlockKind
    public var text: String
    public var sentences: [ReadingSentencePresentation]
    public var inlineRuns: [ReadingInlinePresentation]
    public var sourceRangeDescription: String?
}

public struct ReadingSentencePresentation: Equatable, Sendable {
    public var id: String
    public var blockID: String
    public var sentenceIndex: Int
    public var text: String
    public var selection: ReadingSelectionContext

    public init(
        id: String,
        blockID: String,
        sentenceIndex: Int,
        text: String,
        selection: ReadingSelectionContext
    ) {
        self.id = id
        self.blockID = blockID
        self.sentenceIndex = sentenceIndex
        self.text = text
        self.selection = selection
    }
}

public struct ReadingInlinePresentation: Equatable, Sendable {
    public var role: ReadingInlineRole
    public var text: String
}

public struct ReadingPresentationStyle: Equatable, Sendable {
    public var typographyRoles: Set<ReadingTypographyRole>
    public var colorRoles: Set<ReadingColorRole>
    public var readingWidth: ReadingWidth
    public var lineSpacing: Double
    public var paragraphSpacing: Double
}
