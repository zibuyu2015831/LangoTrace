import LangoTraceCore

enum LearningLanguageDisplayPolicy {
    case onboardingPicker
    case selectedValue
}

extension LearningLanguage {
    func displayTitle(for policy: LearningLanguageDisplayPolicy) -> String {
        switch policy {
        case .onboardingPicker:
            let interfaceLanguageCode = LocalizedChromeLanguageResolver.preferredLanguageCodes.first ?? "en"
            if interfaceLanguageCode == "zh-Hans" {
                return nativeName == zhHansName ? nativeName : "\(nativeName)（\(zhHansName)）"
            }
            return nativeName == englishName ? nativeName : "\(nativeName) (\(englishName))"
        case .selectedValue:
            return nativeName
        }
    }
}
