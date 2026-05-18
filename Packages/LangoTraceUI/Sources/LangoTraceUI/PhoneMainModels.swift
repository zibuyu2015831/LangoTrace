enum PhoneUnavailableAction: String {
    case photoWriting
    case listenOne

    var content: UnavailableCapabilityContent {
        switch self {
        case .photoWriting:
            .photoWriting
        case .listenOne:
            .listenOne
        }
    }
}
