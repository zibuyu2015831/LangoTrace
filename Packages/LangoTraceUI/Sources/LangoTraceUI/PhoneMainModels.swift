enum PhoneUnavailableAction: String {
    case photoWriting

    var content: UnavailableCapabilityContent {
        switch self {
        case .photoWriting:
            .photoWriting
        }
    }
}
