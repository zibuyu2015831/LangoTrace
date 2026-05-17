public struct OnboardingDraft: Equatable, Sendable {
    public var nativeLanguage: String
    public var targetLanguage: String
    public var level: LanguageLevel

    public init(
        nativeLanguage: String = "中文",
        targetLanguage: String = "英语",
        level: LanguageLevel = .b1
    ) {
        self.nativeLanguage = nativeLanguage
        self.targetLanguage = targetLanguage
        self.level = level
    }

    public func makeLanguageSpacePreview() -> LanguageSpacePreview {
        LanguageSpacePreview(
            id: targetLanguage.lowercased(),
            name: "\(targetLanguage)空间",
            nativeLanguage: nativeLanguage,
            targetLanguage: targetLanguage,
            level: level
        )
    }
}
