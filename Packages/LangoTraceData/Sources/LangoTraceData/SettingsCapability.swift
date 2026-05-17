public enum CapabilityStatus: String, Equatable, Sendable {
    case ready
    case mockOnly
    case unavailable

    public var title: String {
        switch self {
        case .ready:
            "可用"
        case .mockOnly:
            "Local Mock"
        case .unavailable:
            "未接入"
        }
    }
}

public struct SettingsCapability: Equatable, Identifiable, Sendable {
    public enum Kind: String, CaseIterable, Equatable, Hashable, Sendable {
        case languageSpace
        case aiProvider
        case sync
        case localData
        case privacy
        case export

        public var title: String {
            switch self {
            case .languageSpace:
                "语言空间"
            case .aiProvider:
                "AI Provider"
            case .sync:
                "同步"
            case .localData:
                "本地数据"
            case .privacy:
                "隐私边界"
            case .export:
                "导出"
            }
        }

        public var systemImage: String {
            switch self {
            case .languageSpace:
                "text.badge.star"
            case .aiProvider:
                "sparkles"
            case .sync:
                "arrow.triangle.2.circlepath"
            case .localData:
                "externaldrive"
            case .privacy:
                "lock"
            case .export:
                "square.and.arrow.up"
            }
        }
    }

    public let kind: Kind
    public let status: CapabilityStatus
    public let summary: String
    public let detail: String
    public let nextRequirement: String
    public let isReadOnly: Bool

    public var id: Kind {
        kind
    }

    public init(
        kind: Kind,
        status: CapabilityStatus,
        summary: String,
        detail: String,
        nextRequirement: String,
        isReadOnly: Bool = true
    ) {
        self.kind = kind
        self.status = status
        self.summary = summary
        self.detail = detail
        self.nextRequirement = nextRequirement
        self.isReadOnly = isReadOnly
    }
}
