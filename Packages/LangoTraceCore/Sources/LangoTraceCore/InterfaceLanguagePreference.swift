import Foundation

public enum InterfaceLanguagePreference: String, CaseIterable, Equatable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case spanish = "es"
    case japanese = "ja"
    case french = "fr"
    case german = "de"
    case korean = "ko"
    case russian = "ru"

    public static let supportedLanguageCodes = allCases.compactMap(\.languageCode)

    public var id: String {
        storageValue
    }

    public var storageValue: String {
        rawValue
    }

    public var languageCode: String? {
        switch self {
        case .system:
            nil
        case .english, .simplifiedChinese, .spanish, .japanese, .french, .german, .korean, .russian:
            rawValue
        }
    }

    public var englishTitle: String {
        switch self {
        case .system:
            "System"
        case .english:
            "English"
        case .simplifiedChinese:
            "Simplified Chinese"
        case .spanish:
            "Spanish"
        case .japanese:
            "Japanese"
        case .french:
            "French"
        case .german:
            "German"
        case .korean:
            "Korean"
        case .russian:
            "Russian"
        }
    }

    public var zhHansTitle: String {
        switch self {
        case .system:
            "跟随系统"
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        case .spanish:
            "Español"
        case .japanese:
            "日本語"
        case .french:
            "Français"
        case .german:
            "Deutsch"
        case .korean:
            "한국어"
        case .russian:
            "Русский"
        }
    }

    public init(storageValue: String) {
        self = Self(rawValue: storageValue) ?? .system
    }

    public func resolvedLanguageCode(systemLanguageCodes: [String]) -> String {
        if let languageCode {
            return languageCode
        }

        return systemLanguageCodes.lazy.compactMap(Self.supportedLanguageCode(matching:)).first ?? "en"
    }

    public func applying(to languageSpace: LanguageSpacePreview) -> LanguageSpacePreview {
        languageSpace
    }

    private static func supportedLanguageCode(matching languageCode: String) -> String? {
        let normalized = languageCode.replacingOccurrences(of: "_", with: "-")

        if normalized == "zh-Hans" || normalized.hasPrefix("zh-Hans-") {
            return "zh-Hans"
        }

        for code in supportedLanguageCodes where code != "zh-Hans" {
            if normalized == code || normalized.hasPrefix("\(code)-") {
                return code
            }
        }

        return nil
    }
}
