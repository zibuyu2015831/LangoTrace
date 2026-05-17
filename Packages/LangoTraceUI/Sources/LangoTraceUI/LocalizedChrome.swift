import LangoTraceCore
import LangoTraceData
import SwiftUI

func localizedText(_ key: String) -> Text {
    Text(LocalizedStringKey(key), bundle: .module)
}

func interfaceLanguagePreferenceTitleKey(for preference: InterfaceLanguagePreference) -> String {
    switch preference {
    case .system:
        "settings.interfaceLanguage.system"
    case .english:
        "settings.interfaceLanguage.english"
    case .simplifiedChinese:
        "settings.interfaceLanguage.zhHans"
    }
}

extension PhoneRootTab {
    var localizedTitleKey: String {
        switch self {
        case .today:
            "tab.today"
        case .entries:
            "tab.entries"
        case .practice:
            "tab.practice"
        case .memory:
            "tab.memory"
        case .settings:
            "tab.settings"
        }
    }
}

extension CapabilityStatus {
    var localizedTitleKey: String {
        switch self {
        case .ready:
            "capabilityStatus.ready"
        case .mockOnly:
            "capabilityStatus.mockOnly"
        case .unavailable:
            "capabilityStatus.unavailable"
        }
    }
}

extension SettingsCapability.Kind {
    var localizedTitleKey: String {
        switch self {
        case .languageSpace:
            "settings.languageSpace.title"
        case .interfaceLanguage:
            "settings.interfaceLanguage.title"
        case .aiProvider:
            "settings.aiProvider.title"
        case .sync:
            "settings.sync.title"
        case .localData:
            "settings.localData.title"
        case .privacy:
            "settings.privacy.title"
        case .export:
            "settings.export.title"
        }
    }
}
