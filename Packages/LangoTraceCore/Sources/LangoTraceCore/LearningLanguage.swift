public struct LearningLanguage: Equatable, Sendable, Identifiable {
    public let code: String
    public let nativeName: String
    public let zhHansName: String
    public let englishName: String

    public var id: String {
        code
    }

    public var defaultSpaceName: String {
        "\(zhHansName)空间"
    }

    public var promptLanguageName: String {
        englishName
    }
}

public extension LearningLanguage {
    static let zhHans = LearningLanguage(
        code: "zh-Hans",
        nativeName: "中文",
        zhHansName: "中文",
        englishName: "Chinese"
    )

    static let english = LearningLanguage(
        code: "en",
        nativeName: "English",
        zhHansName: "英语",
        englishName: "English"
    )

    static let japanese = LearningLanguage(
        code: "ja",
        nativeName: "日本語",
        zhHansName: "日语",
        englishName: "Japanese"
    )

    static let korean = LearningLanguage(
        code: "ko",
        nativeName: "한국어",
        zhHansName: "韩语",
        englishName: "Korean"
    )

    static let french = LearningLanguage(
        code: "fr",
        nativeName: "Français",
        zhHansName: "法语",
        englishName: "French"
    )

    static let german = LearningLanguage(
        code: "de",
        nativeName: "Deutsch",
        zhHansName: "德语",
        englishName: "German"
    )

    static let spanish = LearningLanguage(
        code: "es",
        nativeName: "Español",
        zhHansName: "西班牙语",
        englishName: "Spanish"
    )

    static let supportedNativeLanguages: [LearningLanguage] = [
        .zhHans,
        .english,
        .japanese,
        .korean,
        .french,
        .german,
        .spanish,
    ]

    static let supportedTargetLanguages: [LearningLanguage] = [
        .english,
        .japanese,
        .french,
        .german,
        .spanish,
        .korean,
        .zhHans,
    ]

    static let defaultNative = LearningLanguage.zhHans
    static let defaultTarget = LearningLanguage.english

    static func find(code: String) -> LearningLanguage? {
        supportedNativeLanguages.first { $0.code == code }
    }

    static func targetLanguages(excludingNativeCode nativeLanguageCode: String) -> [LearningLanguage] {
        supportedTargetLanguages.filter { $0.code != nativeLanguageCode }
    }
}
