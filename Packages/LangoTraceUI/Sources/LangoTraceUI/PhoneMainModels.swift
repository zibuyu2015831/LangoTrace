enum PhoneUnavailableAction: String {
    case photoWriting
    case listenOne
    case languageSwitcher

    var title: String {
        switch self {
        case .photoWriting:
            "照片写作尚未接入"
        case .listenOne:
            "听一句尚未接入"
        case .languageSwitcher:
            "语言空间切换尚未接入"
        }
    }

    var summary: String {
        switch self {
        case .photoWriting:
            "当前页面只补齐入口反馈，不访问照片库，也不会启动 OCR 或 AI 生成。"
        case .listenOne:
            "当前页面只展示入口边界，不播放真实 TTS、不录音、不保存练习结果。"
        case .languageSwitcher:
            "当前只有一个内存语言空间 preview，不会创建、切换或持久化多语言空间。"
        }
    }

    var nextRequirement: String {
        switch self {
        case .photoWriting:
            "接入 PhotosUI、OCR / Vision、附件存储、请求预览和用户确认流程。"
        case .listenOne:
            "接入 TTS、播放控制、练习会话状态和可取消的语音服务边界。"
        case .languageSwitcher:
            "完成语言空间持久化、最近使用空间恢复和多空间选择 UI。"
        }
    }

    var systemImage: String {
        switch self {
        case .photoWriting:
            "camera"
        case .listenOne:
            "play"
        case .languageSwitcher:
            "text.badge.star"
        }
    }
}
