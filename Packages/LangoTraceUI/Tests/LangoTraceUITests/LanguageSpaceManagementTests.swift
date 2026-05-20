import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Language space management")
struct LanguageSpaceManagementTests {
    @Test("Management source keeps persistence outside the view")
    func managementSourceKeepsPersistenceOutsideView() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceManagementView.swift"), encoding: .utf8)

        #expect(source.contains("struct LanguageSpaceManagementView"))
        #expect(source.contains("let onAdd"))
        #expect(source.contains("let onSelect"))
        #expect(source.contains("let onUpdate"))
        #expect(source.contains("let onDelete"))
        #expect(!source.contains("GRDB"))
        #expect(!source.contains("DatabaseQueue"))
        #expect(!source.contains("SQL"))
    }

    @Test("Management source contains same target warning and soft delete copy boundary")
    func managementSourceContainsWarningsAndSoftDeleteBoundary() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceManagementView.swift"), encoding: .utf8)

        #expect(source.contains("settings.languageSpace.management.sameTargetLanguageWarning"))
        #expect(source.contains("settings.languageSpace.management.duplicateNameWarning"))
        #expect(source.contains("settings.languageSpace.management.deleteMessage"))
        #expect(source.contains("settings.languageSpace.management.deleteLastSpaceMessage"))
        #expect(!source.contains("永久删除所有本地文件"))
        #expect(!source.contains("彻底清除所有数据"))
    }

    @Test("Management source supports editing existing spaces")
    func managementSourceSupportsEditingExistingSpaces() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceManagementView.swift"), encoding: .utf8)

        #expect(source.contains("case edit(LanguageSpace)"))
        #expect(source.contains("settings.languageSpace.management.rename"))
        #expect(source.contains("UpdateLanguageSpaceInput"))
        #expect(source.contains("onUpdate(space.id, input)"))
        #expect(source.contains(".id(space.updatedAt)"))
    }

    @Test("Phone settings route opens the management page instead of summary only")
    func phoneSettingsRouteOpensManagementPage() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)

        #expect(source.contains("LanguageSpaceManagementView"))
        #expect(source.contains("case .settings(.languageSpace)"))
        #expect(source.contains("onUpdate: onUpdateLanguageSpace"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
