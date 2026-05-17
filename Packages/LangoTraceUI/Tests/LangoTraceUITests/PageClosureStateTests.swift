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
        #expect(PadFooterAction.aiProvider.route == .settings(.aiProvider))
        #expect(PadFooterAction.sync.route == .settings(.sync))
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
        #expect(MacFooterAction.aiProvider.route == .settings(.aiProvider))
        #expect(MacFooterAction.sync.section == .settings)
        #expect(MacFooterAction.sync.route == .settings(.sync))
        #expect(MacFooterAction.settings.section == .settings)
        #expect(MacFooterAction.settings.route == .overview)
    }
}
