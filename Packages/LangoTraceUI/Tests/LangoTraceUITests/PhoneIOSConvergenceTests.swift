import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Phone iOS convergence")
struct PhoneIOSConvergenceTests {
    @Test("iPhone memory page hides technical memory infrastructure")
    func iPhoneMemoryPageHidesTechnicalMemoryInfrastructure() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PhoneMainSections.swift"), encoding: .utf8)

        #expect(!source.contains("MemoryLayerSummaryView("))
        #expect(!source.contains("memory.vectorIndex.title"))
        #expect(!source.contains("memory.vectorIndex.body"))
    }

    @Test("iPhone record hero keeps photo writing and moves listening to practice")
    func iPhoneRecordHeroKeepsPhotoWritingAndMovesListeningToPractice() throws {
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let photoWritingPreview = try String(
            contentsOf: sourceFileURL(named: "PhonePhotoWritingPreviewView.swift"),
            encoding: .utf8
        )
        let practiceRows = try String(contentsOf: sourceFileURL(named: "PhonePracticeRows.swift"), encoding: .utf8)
        let sections = try String(contentsOf: sourceFileURL(named: "PhoneMainSections.swift"), encoding: .utf8)

        #expect(phoneMainView.contains("case .photoWritingPreview"))
        #expect(phoneMainView.contains("createMockPhotoWritingEntry()"))
        #expect(photoWritingPreview.contains("PhotoWritingPreviewView"))
        #expect(supportingViews.contains("photoWriting.startWithPhoto"))
        #expect(!supportingViews.contains(#"SecondaryActionChip(titleKey: "common.listen""#))
        #expect(practiceRows.contains("PracticeContinuePanel"))
        #expect(sections.contains("PracticeContinuePanel"))
    }

    @Test("iPhone default learning flow does not show persistent request previews")
    func iPhoneDefaultLearningFlowDoesNotShowPersistentRequestPreviews() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let header = try String(contentsOf: sourceFileURL(named: "EntryDetailHeader.swift"), encoding: .utf8)

        #expect(!supportingViews.contains("RequestPreviewCard(entry:"))
        #expect(!header.contains("entryDetail.header.boundary"))
        #expect(!supportingViews.contains("entryDetail.sentences.subtitle"))
        #expect(!supportingViews.contains("entryDetail.practiceEntry.subtitle"))
    }

    @Test("iPhone detail owns real generation entry while iPad and Mac stay unconnected")
    func iPhoneDetailOwnsRealGenerationEntry() throws {
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let padSections = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let macWorkspace = try String(
            contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"),
            encoding: .utf8
        )

        #expect(phoneMainView.contains("onGenerateLearningMaterial"))
        #expect(phoneMainView.contains("contentStore.generateLearningMaterial"))
        #expect(supportingViews.contains("entry.rendering.generateLearningMaterial.title"))
        #expect(supportingViews.contains("entry.rendering.generateLearningMaterial.summary"))
        #expect(!padSections.contains("generateLearningMaterial"))
        #expect(!macWorkspace.contains("generateLearningMaterial"))
    }

    @Test("iPhone detail supports editable learning text and reanalysis")
    func iPhoneDetailSupportsEditableLearningTextAndReanalysis() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)

        #expect(supportingViews.contains("LearningMaterialEditorView"))
        #expect(supportingViews.contains("EntryTextEditorSurface("))
        #expect(supportingViews.contains("entry.rendering.learningText.save"))
        #expect(supportingViews.contains("entry.rendering.learningText.reanalyze"))
        #expect(supportingViews.contains("entry.rendering.learningText.analyzing"))
        #expect(supportingViews.contains("entry.rendering.learningText.analysisFailed"))
        #expect(phoneMainView.contains("contentStore.updateLearningText"))
        #expect(phoneMainView.contains("contentStore.analyzeCurrentLearningText"))
    }

    @Test("iPhone detail uses dynamic text cards without squeezing reading columns")
    func iPhoneDetailUsesDynamicTextCardsWithoutSqueezingReadingColumns() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)

        #expect(supportingViews.contains("private struct EntryDetailTextCard"))
        #expect(supportingViews.contains("private struct LearningMaterialEditorView"))
        #expect(supportingViews.contains("private struct SourceEntryEditorSheet"))
        #expect(supportingViews.contains("private struct LearningMaterialEditorSheet"))
        #expect(!supportingViews.contains("private struct ReadOnlyEntryTextPanel: View"))
        #expect(!supportingViews.contains("ZStack(alignment: .topTrailing)"))
        #expect(!supportingViews.contains("textTrailingPadding"))
        #expect(supportingViews.contains("targetLanguageName: languageSpace.targetLanguage"))
        #expect(supportingViews.contains("nativeLanguageName: languageSpace.nativeLanguage"))
        #expect(supportingViews.contains("let targetLanguageName: String"))
        #expect(supportingViews.contains("let nativeLanguageName: String"))
        #expect(supportingViews.contains("entry.detail.sourceText.titleFormat"))
        #expect(supportingViews.contains("entry.detail.learningText.titleFormat"))
        #expect(supportingViews.contains("entry.detail.sourceText.edit"))
        #expect(supportingViews.contains("entry.detail.learningText.sourceStale"))
        #expect(supportingViews.contains("entry.detail.learningText.regenerate"))
        #expect(supportingViews.contains("HStack(alignment: .center, spacing: 12)"))
        #expect(supportingViews.contains(".font(.subheadline.weight(.semibold))"))
        #expect(supportingViews.contains("foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)"))
        #expect(supportingViews.contains(".frame(minHeight: 44, alignment: .center)"))
        #expect(supportingViews.contains("private struct EntryTextEditorSurface"))
        #expect(supportingViews.contains("RoundedRectangle(cornerRadius: 12, style: .continuous)"))
        #expect(supportingViews.contains("@State private var isEditorPresented = false"))
        #expect(supportingViews.contains(".sheet(isPresented: $isEditorPresented)"))
        #expect(supportingViews.contains(".presentationDetents([.large])"))
        #expect(supportingViews.contains("entry.rendering.learningText.edit"))
        #expect(supportingViews.contains("entry.rendering.learningText.editTitle"))
        #expect(supportingViews.contains(
            "localizedString(\"entry.rendering.learningText.editTitle\", targetLanguageName)"
        ))
        #expect(supportingViews.contains("navigationTitle(sheetTitle)"))
        #expect(supportingViews.contains(".langoPanel(padding: 14)"))
        #expect(phoneMainView.contains("contentStore.updateEntryBody"))
        #expect(phoneMainView.contains("contentStore.sourceEntryIsStale"))
        #expect(!supportingViews.contains("private var editingLearningText: some View"))
        #expect(!supportingViews.contains("private var actionRow: some View"))
        #expect(!supportingViews.contains("localizedText(\"entry.targetLanguage.title\")"))
        #expect(!supportingViews.contains(
            "TextPanel(title: localizedString(\"entry.nativeRecord.title\"), text: entry.body)"
        ))
        #expect(!supportingViews.contains(".frame(minHeight: 88, maxHeight: 132)"))
        #expect(!supportingViews.contains(".overlay {\n                RoundedRectangle(cornerRadius: 8"))
        #expect(!supportingViews.contains(".frame(minHeight: 150)"))
    }

    @Test("iPhone sentence listening stays inline instead of opening a sheet")
    func iPhoneSentenceListeningStaysInlineInsteadOfOpeningSheet() throws {
        let components = try String(
            contentsOf: sourceFileURL(named: "LearningContentComponents.swift"),
            encoding: .utf8
        )
        let controls = try String(
            contentsOf: sourceFileURL(named: "SentencePairActionControls.swift"),
            encoding: .utf8
        )

        #expect(components.contains("@State private var isLocalPlaybackActive = false"))
        #expect(components.contains("isListening: isLocalPlaybackActive"))
        #expect(components.contains("isLocalPlaybackActive.toggle()"))
        #expect(!components.contains("LocalListeningPreviewView"))
        #expect(!components.contains(".sheet(isPresented: $isListeningPreviewPresented)"))
        #expect(!components.contains("isListeningPreviewPresented"))
        #expect(controls.contains("let isListening: Bool"))
        #expect(controls.contains("systemImage: isListening ? \"pause.fill\" : \"speaker.wave.2\""))
        #expect(controls.contains("titleKey: isListening ? \"common.pause\" : \"common.listen\""))
        #expect(!components.contains("UnavailableCapabilityView(content: ." + "listenOne)"))
    }

    @Test("iPhone sentence card keeps actions outside the reading column")
    func iPhoneSentenceCardKeepsActionsOutsideReadingColumn() throws {
        let components = try String(
            contentsOf: sourceFileURL(named: "LearningContentComponents.swift"),
            encoding: .utf8
        )
        let controls = try String(
            contentsOf: sourceFileURL(named: "SentencePairActionControls.swift"),
            encoding: .utf8
        )

        #expect(components.contains("SentencePairActionRow("))
        #expect(controls.contains("SentencePairActionButton("))
        #expect(controls.contains(".frame(minWidth: 44, minHeight: 44)"))
        #expect(components.contains(".langoPanel(padding: 14)"))
        #expect(components.contains(".font(.body.weight(.semibold))"))
        #expect(!components.contains("Spacer()\n            HStack(spacing: 8)"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
