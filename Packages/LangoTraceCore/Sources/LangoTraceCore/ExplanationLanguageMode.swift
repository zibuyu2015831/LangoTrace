public enum ExplanationLanguageMode: String, CaseIterable, Codable, Sendable {
    case sourceLanguage
    case bilingualBridge
    case targetImmersion

    public static func derive(from levelCode: String) -> ExplanationLanguageMode {
        switch levelCode {
        case LanguageLevel.a1.rawValue, LanguageLevel.a2.rawValue:
            return .sourceLanguage
        case LanguageLevel.b1.rawValue, LanguageLevel.b2.rawValue:
            return .bilingualBridge
        case LanguageLevel.c1.rawValue, LanguageLevel.c2.rawValue:
            return .targetImmersion
        default:
            return .bilingualBridge
        }
    }
}
