import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

/// E12 Slice B: the settings row-value presentation resolves a localized trailing value for
/// the rows that carry one, and nil for the rows that do not. Also covers the projection →
/// CapabilityStatus mapping used by the iPad learning panel.
@Suite("Settings row value presentation")
struct SettingsRowValuePresentationTests {
    private func value(_ kind: SettingsCapability.Kind, _ status: SettingsStatusProjection = .init()) -> String? {
        settingsRowValue(for: kind, status: status, interfaceLanguage: .system, appearance: .system)
    }

    @Test("rows without a current value return nil")
    func valuelessRows() {
        #expect(value(.languageSpace) == nil)
        #expect(value(.privacy) == nil)
        #expect(value(.importExport) == nil)
    }

    @Test("interface language and appearance rows resolve to a localized value")
    func preferenceRows() {
        #expect(value(.interfaceLanguage) != nil)
        #expect(value(.appearance) != nil)
        #expect(value(.interfaceLanguage) == localizedString("settings.interfaceLanguage.system"))
        #expect(value(.appearance) == localizedString("settings.appearance.system"))
    }

    @Test("AI provider row reflects the projected status")
    func aiProviderRow() {
        #expect(value(.aiProvider, .init(aiProvider: .configured)) == localizedString("settings.value.aiProvider.configured"))
        #expect(value(.aiProvider, .init(aiProvider: .missingKey)) == localizedString("settings.value.aiProvider.missingKey"))
        #expect(value(.aiProvider, .init(aiProvider: .notConfigured)) == localizedString("settings.value.aiProvider.notConfigured"))
    }

    @Test("sync row reflects the projected status")
    func syncRow() {
        #expect(value(.sync, .init(sync: .notEnabled)) == localizedString("settings.value.sync.notEnabled"))
    }

    @Test("local data row formats a byte count when known and shows a placeholder otherwise")
    func localDataRow() {
        let computing = value(.localData, .init(localData: nil))
        #expect(computing == localizedString("settings.value.localData.computing"))

        let known = value(.localData, .init(localData: LocalDataUsage(totalBytes: 5_000_000)))
        #expect(known != nil)
        #expect(known != computing)
        // A formatted size always contains a digit.
        #expect(known?.contains(where: \.isNumber) == true)
    }

    @Test("AI status maps onto the learning panel capability tone")
    func aiCapabilityMapping() {
        #expect(capabilityStatus(forAIProvider: .configured) == .ready)
        #expect(capabilityStatus(forAIProvider: .partiallyAvailable) == .ready)
        #expect(capabilityStatus(forAIProvider: .missingKey) == .unavailable)
        #expect(capabilityStatus(forAIProvider: .notConfigured) == .unavailable)
        #expect(capabilityStatus(forSync: .notEnabled) == .unavailable)
    }

    /// UIV-08 regression: the language-space footer call sites must no longer hard-code the
    /// AI / sync status; they read the projection instead.
    @Test("footer call sites do not hard-code AI or sync status")
    func footerStatusIsNotHardCoded() throws {
        let sourcesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
        for fileName in ["PadMainSections.swift", "MacMainView.swift"] {
            let source = try String(contentsOf: sourcesRoot.appendingPathComponent(fileName), encoding: .utf8)
            #expect(!source.contains("aiStatus: .notConfigured"))
            #expect(!source.contains("syncStatus: .off"))
        }
    }
}
