import Foundation
import LangoTraceCore
import LangoTraceData
import SwiftUI

func localizedText(_ key: String) -> Text {
    Text(localizedString(key))
}

/// Reactive chrome text leaf.
///
/// Unlike the free `localizedText(_:)` (which resolves from the non-observable
/// global resolver and therefore does not re-render on language change), this
/// view reads `@Environment(\.locale)` — injected by the App from the resolved
/// interface-language code — and resolves copy directly from that locale. Reading
/// the environment establishes a SwiftUI dependency, so the leaf re-renders the
/// instant the interface language changes, even when its other inputs are stable.
/// Resolving from the passed locale (not the global box) also avoids any ordering
/// dependency on when the resolver box is written.
struct LocalizedText: View {
    let key: String

    @Environment(\.locale) private var locale

    init(_ key: String) {
        self.key = key
    }

    var body: Text {
        Text(localizedString(key, locale: locale))
    }
}

/// Locale-scoped chrome lookup for the reactive view path. The free
/// `localizedString(_:)` overload keeps reading the global resolver for
/// non-View callers and the App-init early path.
func localizedString(_ key: String, locale: Locale) -> String {
    LocalizedChromeCatalog.shared.localizedString(
        for: key,
        preferredLanguageCodes: [locale.identifier]
    )
}

func localizedString(_ key: String) -> String {
    LocalizedChromeCatalog.shared.localizedString(
        for: key,
        preferredLanguageCodes: LocalizedChromeLanguageResolver.preferredLanguageCodes
    )
}

func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
    let locale = LocalizedChromeLanguageResolver.preferredLanguageCodes.first
        .map { Locale(identifier: $0) }
    return String(format: localizedString(key), locale: locale, arguments: arguments)
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

private final class LanguageOverrideBox: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var codes: [String]?

    func get() -> [String]? {
        lock.lock(); defer { lock.unlock() }
        return codes
    }

    func set(_ newCodes: [String]?) {
        lock.lock(); defer { lock.unlock() }
        codes = newCodes
    }

    func withCode<T>(_ code: String, operation: () throws -> T) rethrows -> T {
        lock.lock()
        let previous = codes
        codes = [code]
        defer {
            codes = previous
            lock.unlock()
        }
        return try operation()
    }
}

enum LocalizedChromeLanguageResolver {
    private static let overrideBox = LanguageOverrideBox()

    static var preferredLanguageCodes: [String] {
        overrideBox.get() ?? ["en"]
    }

    static func use(languageCode: String?) {
        overrideBox.set(languageCode.map { [$0] })
    }

    static func snapshotOverride() -> [String]? {
        overrideBox.get()
    }

    static func restoreOverride(_ languageCodes: [String]?) {
        overrideBox.set(languageCodes)
    }

    static func withLanguageCode<T>(_ languageCode: String, operation: () throws -> T) rethrows -> T {
        try overrideBox.withCode(languageCode, operation: operation)
    }
}

func withLocalizedChromeLanguageCode<T>(_ languageCode: String, operation: () throws -> T) rethrows -> T {
    try LocalizedChromeLanguageResolver.withLanguageCode(languageCode, operation: operation)
}

/// App-facing entry point for applying the interface chrome language outside of
/// SwiftUI view updates. The App initializer must call this once before the first
/// scene body resolves localized chrome strings; preference changes are applied
/// again through the same entry point or the root view's `onChange` path.
public enum LangoTraceInterfaceChrome {
    public static func applyLanguage(
        _ preference: InterfaceLanguagePreference,
        systemLanguageCodes: [String] = Bundle.main.preferredLocalizations
    ) {
        LocalizedChromeLanguageResolver.use(
            languageCode: preference.resolvedLanguageCode(systemLanguageCodes: systemLanguageCodes)
        )
    }
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

func appearancePreferenceTitleKey(for preference: AppearancePreference) -> String {
    switch preference {
    case .system:
        "settings.appearance.system"
    case .light:
        "settings.appearance.light"
    case .dark:
        "settings.appearance.dark"
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
        case .reading:
            "tab.reading"
        case .practice:
            "tab.practice"
        case .memory:
            "tab.memory"
        }
    }
}

extension AIProviderStatus {
    var localizedTitleKey: String {
        "privacyStatus.ai.title"
    }

    var localizedValueKey: String {
        switch self {
        case .notConfigured:
            "privacyStatus.ai.value.notConfigured"
        case .configured:
            "privacyStatus.ai.value.configured"
        case .unavailable:
            "privacyStatus.ai.value.unavailable"
        case .error:
            "privacyStatus.ai.value.error"
        }
    }

    var localizedSummaryKey: String {
        switch self {
        case .notConfigured:
            "privacyStatus.ai.summary.notConfigured"
        case .configured:
            "privacyStatus.ai.summary.configured"
        case .unavailable:
            "privacyStatus.ai.summary.unavailable"
        case .error:
            "privacyStatus.ai.summary.error"
        }
    }
}

extension SyncProviderStatus {
    var localizedTitleKey: String {
        "privacyStatus.sync.title"
    }

    var localizedValueKey: String {
        switch self {
        case .off:
            "privacyStatus.sync.value.off"
        case .configured:
            "privacyStatus.sync.value.configured"
        case .syncing:
            "privacyStatus.sync.value.syncing"
        case .paused:
            "privacyStatus.sync.value.paused"
        case .error:
            "privacyStatus.sync.value.error"
        }
    }

    var localizedSummaryKey: String {
        switch self {
        case .off:
            "privacyStatus.sync.summary.off"
        case .configured:
            "privacyStatus.sync.summary.configured"
        case .syncing:
            "privacyStatus.sync.summary.syncing"
        case .paused:
            "privacyStatus.sync.summary.paused"
        case .error:
            "privacyStatus.sync.summary.error"
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
        case .appearance:
            "settings.appearance.title"
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
