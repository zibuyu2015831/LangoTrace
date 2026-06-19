public enum AppearancePreference: String, CaseIterable, Equatable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String {
        storageValue
    }

    public var storageValue: String {
        rawValue
    }

    public init(storageValue: String) {
        self = Self(rawValue: storageValue) ?? .system
    }
}
