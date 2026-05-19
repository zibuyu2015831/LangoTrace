public enum CapabilityStatus: String, Equatable, Sendable {
    case ready
    case mockOnly
    case unavailable

    public var title: String {
        rawValue
    }
}

public struct SettingsCapability: Equatable, Identifiable, Sendable {
    public enum Kind: String, CaseIterable, Equatable, Hashable, Sendable {
        case languageSpace
        case interfaceLanguage
        case aiProvider
        case sync
        case localData
        case privacy
        case importExport

        public var title: String {
            rawValue
        }

        public var systemImage: String {
            switch self {
            case .languageSpace:
                "text.badge.star"
            case .interfaceLanguage:
                "globe"
            case .aiProvider:
                "sparkles"
            case .sync:
                "arrow.triangle.2.circlepath"
            case .localData:
                "externaldrive"
            case .privacy:
                "lock"
            case .importExport:
                "tray.and.arrow.down"
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
