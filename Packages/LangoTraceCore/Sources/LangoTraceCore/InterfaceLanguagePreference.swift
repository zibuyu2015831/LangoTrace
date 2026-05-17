import Foundation

public enum InterfaceLanguagePreference: String, CaseIterable, Equatable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

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
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
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

        if normalized == "en" || normalized.hasPrefix("en-") {
            return "en"
        }

        return nil
    }
}
