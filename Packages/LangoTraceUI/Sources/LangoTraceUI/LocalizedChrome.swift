import Foundation
import LangoTraceCore
import LangoTraceData
import SwiftUI

func localizedText(_ key: String) -> Text {
    Text(localizedString(key))
}

func localizedString(_ key: String) -> String {
    LocalizedChromeCatalog.shared.localizedString(
        for: key,
        preferredLanguageCodes: LocalizedChromeLanguageResolver.preferredLanguageCodes
    )
}

func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedString(key), arguments: arguments)
}

private struct LocalizedChromeCatalog {
    static let shared = LocalizedChromeCatalog()

    private let strings: [String: [String: String]]

    private init() {
        guard
            let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawStrings = root["strings"] as? [String: Any]
        else {
            strings = [:]
            return
        }

        strings = rawStrings.reduce(into: [String: [String: String]]()) { result, element in
            guard
                let entry = element.value as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                return
            }

            result[element.key] = localizations.reduce(into: [String: String]()) { values, localization in
                guard
                    let localizationEntry = localization.value as? [String: Any],
                    let unit = localizationEntry["stringUnit"] as? [String: Any],
                    let value = unit["value"] as? String
                else {
                    return
                }

                values[localization.key] = value
            }
        }
    }

    func localizedString(for key: String, preferredLanguageCodes: [String]) -> String {
        let languageCandidates = languageCandidates(for: preferredLanguageCodes)

        if let localizations = strings[key] {
            for identifier in languageCandidates {
                if let exact = localizations[identifier] {
                    return exact
                }

                let languageCode = identifier.split(separator: "-").first.map(String.init)
                if languageCode == "zh", let simplifiedChinese = localizations["zh-Hans"] {
                    return simplifiedChinese
                }

                if let languageCode, let languageMatch = localizations[languageCode] {
                    return languageMatch
                }
            }

            return localizations["en"] ?? localizations["zh-Hans"] ?? key
        }

        if let compiledValue = compiledLocalizedString(for: key, languageCandidates: languageCandidates) {
            return compiledValue
        }

        return key
    }

    private func compiledLocalizedString(for key: String, languageCandidates: [String]) -> String? {
        for identifier in languageCandidates {
            guard
                let path = Bundle.module.path(forResource: identifier, ofType: "lproj"),
                let bundle = Bundle(path: path)
            else {
                continue
            }

            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key {
                return value
            }
        }

        let fallback = Bundle.module.localizedString(forKey: key, value: nil, table: nil)
        return fallback == key ? nil : fallback
    }

    private func languageCandidates(for preferredLanguageCodes: [String]) -> [String] {
        var candidates: [String] = []

        func append(_ identifier: String) {
            guard !candidates.contains(identifier) else {
                return
            }
            candidates.append(identifier)
        }

        for identifier in preferredLanguageCodes {
            let normalized = identifier.replacingOccurrences(of: "_", with: "-")
            append(normalized)

            if let languageCode = normalized.split(separator: "-").first.map(String.init) {
                if languageCode == "zh" {
                    append("zh-Hans")
                }
                append(languageCode)
            }
        }

        append("en")
        append("zh-Hans")
        return candidates
    }
}

enum LocalizedChromeLanguageResolver {
    private nonisolated(unsafe) static var overrideLanguageCodes: [String]?
    private static let overrideLock = NSRecursiveLock()

    static var preferredLanguageCodes: [String] {
        overrideLock.lock()
        defer {
            overrideLock.unlock()
        }
        return overrideLanguageCodes ?? ["en"]
    }

    static func use(languageCode: String?) {
        overrideLock.lock()
        defer {
            overrideLock.unlock()
        }
        if let languageCode {
            overrideLanguageCodes = [languageCode]
        } else {
            overrideLanguageCodes = nil
        }
    }

    static func snapshotOverride() -> [String]? {
        overrideLock.lock()
        defer {
            overrideLock.unlock()
        }
        return overrideLanguageCodes
    }

    static func restoreOverride(_ languageCodes: [String]?) {
        overrideLock.lock()
        defer {
            overrideLock.unlock()
        }
        overrideLanguageCodes = languageCodes
    }

    static func withLanguageCode<T>(_ languageCode: String, operation: () throws -> T) rethrows -> T {
        overrideLock.lock()
        let previous = overrideLanguageCodes
        overrideLanguageCodes = [languageCode]
        defer {
            overrideLanguageCodes = previous
            overrideLock.unlock()
        }
        return try operation()
    }
}

func withLocalizedChromeLanguageCode<T>(_ languageCode: String, operation: () throws -> T) rethrows -> T {
    try LocalizedChromeLanguageResolver.withLanguageCode(languageCode, operation: operation)
}

func interfaceLanguagePreferenceTitleKey(for preference: InterfaceLanguagePreference) -> String {
    switch preference {
    case .system:
        "settings.interfaceLanguage.system"
    case .english:
        "settings.interfaceLanguage.english"
    case .simplifiedChinese:
        "settings.interfaceLanguage.zhHans"
    case .spanish:
        "settings.interfaceLanguage.spanish"
    case .japanese:
        "settings.interfaceLanguage.japanese"
    case .french:
        "settings.interfaceLanguage.french"
    case .german:
        "settings.interfaceLanguage.german"
    case .korean:
        "settings.interfaceLanguage.korean"
    case .russian:
        "settings.interfaceLanguage.russian"
    }
}

struct SettingsCapabilityDetailLocalizationKeys: Equatable {
    let summary: String
    let detail: String
    let nextRequirement: String
}

let settingsCurrentBoundaryTitleKey = "settings.detail.currentBoundary"
let settingsNextRequirementTitleKey = "settings.detail.nextRequirement"
let settingsNoSideEffectsTitleKey = "settings.detail.noSideEffects"
let settingsNoSideEffectsBodyKey = "settings.detail.noSideEffects.body"

func settingsCapabilityDetailLocalizationKeys(
    for kind: SettingsCapability.Kind
) -> SettingsCapabilityDetailLocalizationKeys {
    let baseKey = "settings.\(kind.rawValue)"
    return SettingsCapabilityDetailLocalizationKeys(
        summary: "\(baseKey).summary",
        detail: "\(baseKey).detail",
        nextRequirement: "\(baseKey).nextRequirement"
    )
}

extension PhoneRootTab {
    var localizedTitleKey: String {
        switch self {
        case .entries:
            "tab.entries"
        case .practice:
            "tab.practice"
        case .memory:
            "tab.memory"
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
        case .importExport:
            "settings.importExport.title"
        }
    }
}

extension EntrySource {
    var localizedTitleKey: String {
        switch self {
        case .typedText:
            "entrySource.typedText"
        case .photoWriting:
            "entrySource.photoWriting"
        case .targetLanguageWriting:
            "entrySource.targetLanguageWriting"
        }
    }
}

extension LearningEntry {
    var displaySourceTitle: String {
        localizedString(source.localizedTitleKey)
    }
}

extension PracticeSessionStep {
    var localizedTitleKey: String {
        switch self {
        case .prepare:
            "practiceStep.prepare"
        case .shadow:
            "practiceStep.shadow"
        case .compare:
            "practiceStep.compare"
        case .completed:
            "practiceStep.completed"
        }
    }

    var displayTitle: String {
        localizedString(localizedTitleKey)
    }
}
