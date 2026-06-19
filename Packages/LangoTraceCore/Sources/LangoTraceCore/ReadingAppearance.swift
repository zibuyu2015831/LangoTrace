public enum ReadingTypographyRole: Equatable, Hashable, Sendable {
    case body
    case heading(level: Int)
    case blockquote
    case listItem
    case codeBlock
}

public enum ReadingInlineRole: Equatable, Hashable, Sendable {
    case plain
    case link
    case inlineCode
    case emphasis
    case strong
}

public enum ReadingColorRole: Equatable, Hashable, Sendable {
    case background
    case foreground
    case secondaryForeground
    case link
    case codeBackground
    case blockquoteAccent
    case darkModeBackground
}

public enum ReadingDynamicTypeStrategy: Equatable, Hashable, Sendable {
    case scaleWithSystem
}

public struct ReadingWidth: Equatable, Hashable, Sendable {
    public var points: Double

    public static func points(_ points: Double) -> ReadingWidth {
        ReadingWidth(points: points)
    }
}

public struct ReadingAppearanceProfile: Equatable, Sendable {
    public var typographyRoles: Set<ReadingTypographyRole>
    public var inlineRoles: Set<ReadingInlineRole>
    public var colorRoles: Set<ReadingColorRole>
    public var readingWidth: ReadingWidth
    public var lineSpacing: Double
    public var paragraphSpacing: Double
    public var dynamicTypeStrategy: ReadingDynamicTypeStrategy

    public static let `default` = ReadingAppearanceProfile(
        typographyRoles: [
            .body,
            .heading(level: 1),
            .heading(level: 2),
            .heading(level: 3),
            .blockquote,
            .listItem,
            .codeBlock,
        ],
        inlineRoles: [.plain, .link, .inlineCode, .emphasis, .strong],
        colorRoles: [
            .background,
            .foreground,
            .secondaryForeground,
            .link,
            .codeBackground,
            .blockquoteAccent,
            .darkModeBackground,
        ],
        readingWidth: .points(640),
        lineSpacing: 5,
        paragraphSpacing: 12,
        dynamicTypeStrategy: .scaleWithSystem
    )
}

public struct ReadingDocumentIdentity: Equatable, Sendable {
    public var bodyHash: String
    public var contentRevision: Int
    public var structureVersion: Int
    public var sourceAnchorID: String
    public var ttsSourceKey: String

    public init(
        bodyHash: String,
        contentRevision: Int,
        structureVersion: Int,
        sourceAnchorID: String,
        ttsSourceKey: String
    ) {
        self.bodyHash = bodyHash
        self.contentRevision = contentRevision
        self.structureVersion = structureVersion
        self.sourceAnchorID = sourceAnchorID
        self.ttsSourceKey = ttsSourceKey
    }

    public func withAppearance(_: ReadingAppearanceProfile) -> ReadingDocumentIdentity {
        self
    }
}

public struct ReadingRenderStyle: Equatable, Sendable {
    public var appearance: ReadingAppearanceProfile

    public init(appearance: ReadingAppearanceProfile = .default) {
        self.appearance = appearance
    }
}
