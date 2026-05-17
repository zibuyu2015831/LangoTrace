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

    public var title: String {
        "AI Provider"
    }

    public var value: String {
        switch self {
        case .notConfigured:
            "未配置"
        case .configured:
            "已配置"
        case .unavailable:
            "暂不可用"
        case .error:
            "需要处理"
        }
    }

    public var summary: String {
        switch self {
        case .notConfigured:
            "当前不会发送文本、照片摘要或相似记忆。配置后，只有在你触发 AI 功能并确认请求预览时才会发送。"
        case .configured:
            "AI 请求会在发送前显示请求预览。API Key 保存在本机安全存储中。"
        case .unavailable:
            "当前平台、网络、权限或配置条件导致 AI 能力暂不可用。"
        case .error:
            "AI Provider 配置存在错误或最近一次请求失败。请在设置中检查 Provider、模型和密钥。"
        }
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

    public var title: String {
        "同步"
    }

    public var value: String {
        switch self {
        case .off:
            "未启用"
        case .configured:
            "已配置"
        case .syncing:
            "同步中"
        case .paused:
            "已暂停"
        case .error:
            "需要处理"
        }
    }

    public var summary: String {
        switch self {
        case .off:
            "数据仅保存在本机。你可以稍后配置 iCloud、WebDAV、S3 或 R2。"
        case .configured:
            "仅同步你配置范围内的数据。密钥和未选择的数据不会进入同步内容。"
        case .syncing:
            "正在同步配置范围内的数据。同步不会包含密钥或未选择的历史记录。"
        case .paused:
            "同步已暂停。数据继续保存在本机，恢复后再同步配置范围内的数据。"
        case .error:
            "同步失败或配置失效。请在设置中检查目标位置、权限和网络状态。"
        }
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
