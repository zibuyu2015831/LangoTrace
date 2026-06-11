import Foundation
import LangoTraceCore
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

    @Test("Management source keeps guidance in context instead of a persistent card")
    func managementSourceKeepsGuidanceInContextInsteadOfPersistentCard() throws {
        let source = try sourceText(
            named: "LanguageSpaceManagementView.swift",
            "LanguageSpaceEditorView.swift"
        )

        #expect(!source.contains("settings.languageSpace.management.sameTargetLanguageWarning"))
        #expect(source.contains("settings.languageSpace.management.duplicateNameWarning"))
        #expect(source.contains("settings.languageSpace.management.deleteMessage"))
        #expect(source.contains("settings.languageSpace.management.deleteLastSpaceMessage"))
        #expect(!source.contains("private var guidanceSection"))
        #expect(!source.contains("永久删除所有本地文件"))
        #expect(!source.contains("彻底清除所有数据"))
    }

    @Test("Management source supports editing existing spaces")
    func managementSourceSupportsEditingExistingSpaces() throws {
        let source = try sourceText(
            named: "LanguageSpaceManagementView.swift",
            "LanguageSpaceEditorView.swift"
        )

        #expect(source.contains("case edit(LanguageSpace)"))
        #expect(source.contains("settings.languageSpace.management.edit"))
        #expect(source.contains("settings.languageSpace.management.editTitle"))
        #expect(!source.contains("settings.languageSpace.management.rename"))
        #expect(source.contains("UpdateLanguageSpaceInput"))
        #expect(source.contains("onUpdate(space.id, input)"))
        // ForEach identity must come from the stable space ID; `.id(space.updatedAt)`
        // overrode row identity and is intentionally gone.
        #expect(!source.contains(".id(space.updatedAt)"))
    }

    @Test("Editor validation keeps native and target languages distinct")
    func editorValidationKeepsNativeAndTargetLanguagesDistinct() {
        let normalized = LanguageSpaceEditorValidation.normalizedTargetLanguageCode(
            nativeLanguageCode: "en",
            targetLanguageCode: "en"
        )

        #expect(normalized != "en")
        #expect(LearningLanguage.find(code: normalized) != nil)

        let unchanged = LanguageSpaceEditorValidation.normalizedTargetLanguageCode(
            nativeLanguageCode: "zh-Hans",
            targetLanguageCode: "en"
        )
        #expect(unchanged == "en")
    }

    @Test("Editor save stays disabled for same-language or unknown codes")
    func editorSaveStaysDisabledForSameLanguageOrUnknownCodes() {
        #expect(!LanguageSpaceEditorValidation.canSave(nativeLanguageCode: "en", targetLanguageCode: "en"))
        #expect(!LanguageSpaceEditorValidation.canSave(nativeLanguageCode: "", targetLanguageCode: "en"))
        #expect(!LanguageSpaceEditorValidation.canSave(nativeLanguageCode: "zh-Hans", targetLanguageCode: "xx"))
        #expect(LanguageSpaceEditorValidation.canSave(nativeLanguageCode: "zh-Hans", targetLanguageCode: "en"))
    }

    @Test("Editor adjusts target language when native language changes into a collision")
    func editorAdjustsTargetLanguageOnNativeChangeCollision() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceEditorView.swift"), encoding: .utf8)

        #expect(source.contains(".onChange(of: nativeLanguageCode)"))
        #expect(source.contains("LanguageSpaceEditorValidation.normalizedTargetLanguageCode("))
        #expect(source.contains(".disabled(!LanguageSpaceEditorValidation.canSave("))
    }

    @Test("Management editor uses existing localized picker keys")
    func managementEditorUsesExistingLocalizedPickerKeys() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceEditorView.swift"), encoding: .utf8)

        #expect(source.contains("localizedString(\"onboarding.nativeLanguage\")"))
        #expect(source.contains("localizedString(\"onboarding.targetLanguage\")"))
        #expect(!source.contains("onboarding.nativeLanguage.title"))
        #expect(!source.contains("onboarding.targetLanguage.title"))
    }

    @Test("Same target language warning is removed from the editor")
    func sameTargetLanguageWarningIsRemovedFromEditor() throws {
        let catalog = try String(
            contentsOf: sourceFileURL(named: "Resources/Localizable.xcstrings"),
            encoding: .utf8
        )

        #expect(!catalog.contains("\"settings.languageSpace.management.sameTargetLanguageWarning\""))
        #expect(!catalog.contains("One space per learning language"))
        #expect(!catalog.contains("同一学习语言通常一个空间即可"))
        #expect(!catalog.contains("工作、旅行、生活等内容可用标签或场景区分"))
        #expect(!catalog.contains("Use tags or scenes for work, travel, and daily life"))
    }

    @Test("Management editor opens as a compact expandable sheet on iOS")
    func managementEditorOpensAsCompactExpandableSheetOnIOS() throws {
        let source = try sourceText(
            named: "LanguageSpaceManagementView.swift",
            "LanguageSpaceEditorView.swift"
        )

        #expect(source.contains("langoEditorSheetPresentation"))
        #expect(source.contains("presentationDetents([.medium, .large])"))
        #expect(source.contains(".presentationDragIndicator(.visible)"))
        #expect(source.contains("#if os(iOS)"))
    }

    @Test("Management editor uses a branded compact panel instead of a default Form")
    func managementEditorUsesBrandedCompactPanel() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceEditorView.swift"), encoding: .utf8)

        #expect(!source.contains("Form {"))
        #expect(source.contains("LanguageSpaceEditorCard"))
        #expect(source.contains("LanguageSpaceEditorFieldRow"))
        #expect(source.contains("LangoTraceDesign.ColorToken.paper.ignoresSafeArea()"))
        #expect(source.contains(".pickerStyle(.menu)"))
        #expect(source.contains(".langoPanel(padding: 0)"))
    }

    @Test("Current language space is styled as row state instead of a check button")
    func currentLanguageSpaceIsStyledAsRowStateInsteadOfCheckButton() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceManagementView.swift"), encoding: .utf8)

        #expect(!source.contains("checkmark.circle.fill"))
        #expect(source.contains("currentPill"))
        #expect(source.contains("ColorToken.surfaceSelected"))
        #expect(source.contains("RoundedRectangle(cornerRadius: 2"))
        #expect(source.contains("accessibilityValue"))
    }

    @Test("Management keeps swipe edit and delete shortcuts")
    func managementKeepsSwipeEditAndDeleteShortcuts() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceManagementView.swift"), encoding: .utf8)

        #expect(source.contains(".swipeActions(edge: .trailing)"))
        #expect(source.contains("settings.languageSpace.management.edit"))
        #expect(source.contains("settings.languageSpace.management.delete"))
        #expect(source.contains("Button(role: .destructive)"))
        #expect(source.contains("pendingDelete = space"))
    }

    @Test("Management presents one consolidated spaces list")
    func managementPresentsOneConsolidatedSpacesList() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceManagementView.swift"), encoding: .utf8)

        #expect(!source.contains("currentSection"))
        #expect(source.contains("allSpacesSection"))
        #expect(source.contains("space.id == currentSpaceID"))
        #expect(source.contains("ColorToken.surfaceSelected"))
    }

    @Test("Phone settings route opens the management page instead of summary only")
    func phoneSettingsRouteOpensManagementPage() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)

        #expect(source.contains("LanguageSpaceManagementView"))
        #expect(source.contains("case .settings(.languageSpace)"))
        #expect(source.contains("onUpdate: onUpdateLanguageSpace"))
    }

    @Test("iPad routes language-space entry to full management")
    func iPadRoutesLanguageSpaceEntryToFullManagement() throws {
        let source = try sourceText(
            named: "PadMainView.swift",
            "PadMainSections.swift",
            "PadMainModels.swift",
            "LangoTraceRootView.swift"
        )

        #expect(source.contains("case languageSpaceManagement"))
        #expect(source.contains("LanguageSpaceManagementView("))
        #expect(source.contains("spaces: languageSpaces"))
        #expect(source.contains("currentSpaceID: languageSpace.id"))
        #expect(source.contains("onAdd: onAddLanguageSpace"))
        #expect(source.contains("onSelect: onSelectLanguageSpace"))
        #expect(source.contains("onUpdate: onUpdateLanguageSpace"))
        #expect(source.contains("onDelete: onDeleteLanguageSpace"))
        #expect(!source.contains("case .languageSpaceSummary"))
    }

    @Test("macOS workspace routes language-space entry to full management")
    func macOSWorkspaceRoutesLanguageSpaceEntryToFullManagement() throws {
        let source = try sourceText(
            named: "MacMainView.swift",
            "MacWorkspaceContentView.swift",
            "MacMainModels.swift",
            "LangoTraceRootView.swift"
        )

        #expect(source.contains("case languageSpaceManagement"))
        #expect(source.contains("LanguageSpaceManagementView("))
        #expect(source.contains("spaces: languageSpaces"))
        #expect(source.contains("currentSpaceID: languageSpace.id"))
        #expect(source.contains("onAdd: onAddLanguageSpace"))
        #expect(source.contains("onSelect: onSelectLanguageSpace"))
        #expect(source.contains("onUpdate: onUpdateLanguageSpace"))
        #expect(source.contains("onDelete: onDeleteLanguageSpace"))
        #expect(!source.contains("case .languageSpaceSummary"))
    }

    @Test("macOS workspace keeps management list outside the outer scroll view")
    func macOSWorkspaceKeepsManagementListOutsideOuterScrollView() throws {
        let source = try sourceText(named: "MacMainView.swift", "MacMainModels.swift")

        #expect(source.contains("if route.usesDedicatedMainScrolling"))
        #expect(source.contains("mainContent"))
        #expect(source.contains("ScrollView"))
        #expect(source.contains(".languageSpaceManagement"))
        #expect(source.contains("var usesDedicatedMainScrolling: Bool"))
    }

    @Test("macOS management offers pointer-discoverable edit and delete actions")
    func macOSManagementOffersPointerDiscoverableEditAndDeleteActions() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceManagementView.swift"), encoding: .utf8)

        #expect(source.contains(".contextMenu"))
        #expect(source.contains("pendingDelete = space"))
        #expect(source.contains(
            "Label(localizedString(\"settings.languageSpace.management.delete\"), systemImage: \"trash\")"
        ))
        #expect(source.contains("ToolbarItem(placement: .primaryAction)"))
    }

    @Test("macOS Settings scene includes language-space management with lifecycle actions")
    func macOSSettingsSceneIncludesLanguageSpaceManagementWithLifecycleActions() throws {
        let settingsSceneSource = try String(
            contentsOf: sourceFileURL(named: "LangoTraceSettingsSceneView.swift"),
            encoding: .utf8
        )
        let appSource = try String(contentsOf: appSourceFileURL(named: "LangoTraceApp.swift"), encoding: .utf8)
        let source = settingsSceneSource + "\n" + appSource

        #expect(source.contains("languageSpaces: [LanguageSpace]"))
        #expect(source.contains("onAddLanguageSpace"))
        #expect(source.contains("onSelectLanguageSpace"))
        #expect(source.contains("onUpdateLanguageSpace"))
        #expect(source.contains("onDeleteLanguageSpace"))
        #expect(source.contains("LanguageSpaceManagementView("))
        #expect(source.contains("languageSpaces: session.languageSpaces"))
        #expect(source.contains("onAddLanguageSpace: session.addLanguageSpace"))
        #expect(source.contains("onDeleteLanguageSpace: session.deleteLanguageSpace"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LangoTraceUI")
            .appendingPathComponent(fileName)
    }

    private func appSourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LangoTraceApp")
            .appendingPathComponent(fileName)
    }

    private func sourceText(named firstFileName: String, _ otherFileNames: String...) throws -> String {
        try ([firstFileName] + otherFileNames)
            .map { try String(contentsOf: sourceFileURL(named: $0), encoding: .utf8) }
            .joined(separator: "\n")
    }
}
