import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Page closure state")
struct PageClosureStateTests {
    @Test("Pad filters include the expected mock records")
    func padFiltersIncludeExpectedRecords() {
        let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
        let entries = repository.entries(for: "en")
        let memory = repository.memoryItems(for: "en")

        #expect(entries.count(where: { PadFilter.all.includes(entry: $0, memoryItems: memory) }) == entries.count)
        #expect(entries.filter { PadFilter.photoWriting.includes(entry: $0, memoryItems: memory) }
            .allSatisfy { $0.source == .photoWriting })
        #expect(entries.filter { PadFilter.memorized.includes(entry: $0, memoryItems: memory) }
            .allSatisfy { entry in
                memory.contains { $0.entryID == entry.id }
            })
    }

    @Test("Pad footer actions route to visible pages")
    func padFooterActionsRouteToVisiblePages() {
        #expect(PadFooterAction.languageSpace.route == .languageSpaceUnavailable)
        #expect(PadFooterAction.aiProvider.route == .settings(SettingsCapability.Kind.aiProvider))
        #expect(PadFooterAction.sync.route == .settings(SettingsCapability.Kind.sync))
        #expect(PadFooterAction.settings.route == .settingsList)
    }

    @Test("Pad workspace pages include iPad-only closure pages")
    func padWorkspacePagesIncludeIPadOnlyClosurePages() {
        #expect(PadWorkspaceRoute.settingsList.navigationTitle == "设置")
        #expect(PadWorkspaceRoute.memory.navigationTitle == "记忆")
        #expect(PadWorkspaceRoute.importExport.navigationTitle == "导入导出")
        #expect(PadWorkspaceRoute.languageSpaceUnavailable.navigationTitle == "语言空间")
    }

    @Test("Mac footer actions route to visible workspace content")
    func macFooterActionsRouteToVisibleWorkspaceContent() {
        #expect(MacFooterAction.languageSpace.section == .settings)
        #expect(MacFooterAction.languageSpace.route == .unavailable("language-space"))
        #expect(MacFooterAction.aiProvider.section == .settings)
        #expect(MacFooterAction.aiProvider.route == .settings(SettingsCapability.Kind.aiProvider))
        #expect(MacFooterAction.sync.section == .settings)
        #expect(MacFooterAction.sync.route == .settings(SettingsCapability.Kind.sync))
        #expect(MacFooterAction.settings.section == .settings)
        #expect(MacFooterAction.settings.route == .overview)
    }

    @Test("Settings capability chrome uses UI localization keys")
    func settingsCapabilityChromeUsesUILocalizationKeys() {
        #expect(SettingsCapability.Kind.interfaceLanguage.localizedTitleKey == "settings.interfaceLanguage.title")
        #expect(SettingsCapability.Kind.aiProvider.localizedTitleKey == "settings.aiProvider.title")
        #expect(CapabilityStatus.ready.localizedTitleKey == "capabilityStatus.ready")
        #expect(CapabilityStatus.mockOnly.localizedTitleKey == "capabilityStatus.mockOnly")
        #expect(CapabilityStatus.unavailable.localizedTitleKey == "capabilityStatus.unavailable")
    }

    @Test("Interface language option keys are stable")
    func interfaceLanguageOptionKeysAreStable() {
        #expect(interfaceLanguagePreferenceTitleKey(for: .system) == "settings.interfaceLanguage.system")
        #expect(interfaceLanguagePreferenceTitleKey(for: .english) == "settings.interfaceLanguage.english")
        #expect(interfaceLanguagePreferenceTitleKey(for: .simplifiedChinese) == "settings.interfaceLanguage.zhHans")
    }
}
