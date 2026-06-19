public enum PrivacyStatusSeverity: Equatable, Sendable {
    case inactive
    case active
    case warning
    case error
}

public enum AIProviderStatus: Equatable, Sendable, CaseIterable {
    case notConfigured
    case configured
    case unavailable
    case error

    public var systemImage: String {
        "sparkles"
    }

    public var severity: PrivacyStatusSeverity {
        switch self {
        case .notConfigured, .unavailable:
            .inactive
        case .configured:
            .active
        case .error:
            .error
        }
    }
}

public enum SyncProviderStatus: Equatable, Sendable, CaseIterable {
    case off
    case configured
    case syncing
    case paused
    case error

    public var systemImage: String {
        "arrow.triangle.2.circlepath"
    }

    public var severity: PrivacyStatusSeverity {
        switch self {
        case .off:
            .inactive
        case .configured, .syncing:
            .active
        case .paused:
            .warning
        case .error:
            .error
        }
    }
}
