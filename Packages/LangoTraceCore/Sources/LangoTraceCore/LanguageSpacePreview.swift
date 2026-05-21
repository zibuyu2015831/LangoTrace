public struct LanguageSpacePreview: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let nativeLanguage: String
    public let targetLanguage: String
    public let targetLanguageCode: String
    public let level: LanguageLevel

    public init(
        id: String,
        name: String,
        nativeLanguage: String,
        targetLanguage: String,
        targetLanguageCode: String? = nil,
        level: LanguageLevel
    ) {
        self.id = id
        self.name = name
        self.nativeLanguage = nativeLanguage
        self.targetLanguage = targetLanguage
        self.targetLanguageCode = targetLanguageCode ?? targetLanguage
        self.level = level
    }

    public var displayContext: String {
        "\(nativeLanguage) -> \(targetLanguage) · \(level.rawValue)"
    }
}
