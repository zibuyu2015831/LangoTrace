enum PhoneUnavailableAction: String {
    case photoWriting
    case listenOne
    case languageSwitcher

    var content: UnavailableCapabilityContent {
        switch self {
        case .photoWriting:
            .photoWriting
        case .listenOne:
            .listenOne
        case .languageSwitcher:
            .languageSpace
        }
    }
}
