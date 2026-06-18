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
        let photoWritingView = try String(
            contentsOf: sourceFileURL(named: "PhotoWritingView.swift"),
            encoding: .utf8
        )
        let practiceRows = try String(contentsOf: sourceFileURL(named: "PhonePracticeRows.swift"), encoding: .utf8)
        let sections = try String(contentsOf: sourceFileURL(named: "PhoneMainSections.swift"), encoding: .utf8)

        #expect(phoneMainView.contains("case .photoWriting"))
        #expect(!phoneMainView.contains("createMockPhotoWritingEntry"))
        #expect(photoWritingView.contains("PhotoWritingView"))
        #expect(photoWritingView.contains("PhotosPicker"))
        #expect(supportingViews.contains("photoWriting.startWithPhoto"))
        #expect(!supportingViews.contains(#"SecondaryActionChip(titleKey: "common.listen""#))
        #expect(practiceRows.contains("PracticeEntryCard"))
        #expect(sections.contains("PracticeEntryCard"))
        #expect(!sections.contains(#"SectionHeader(titleKey: "phone.practice.fromLife.title")"#))
        #expect(!sections.contains("PracticeTaskRow("))
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

    @Test("Entry detail header keeps title only without metadata or availability badge")
    func entryDetailHeaderKeepsTitleOnlyWithoutMetadataOrAvailabilityBadge() throws {
        let header = try String(contentsOf: sourceFileURL(named: "EntryDetailHeader.swift"), encoding: .utf8)

        #expect(header.contains("struct EntryDetailHeader: View"))
        #expect(header.contains("Text(entry.title)"))
        #expect(!header.contains("CapabilityStatusBadge("))
        #expect(!header.contains("EntryRenderingStatus.status(for: rendering)"))
        #expect(!header.contains("entry.displaySourceTitle"))
        #expect(!header.contains("targetLanguage"))
        #expect(!header.contains("entry.scene"))
    }

    @Test("iPhone entry detail uses entry title as navigation title without duplicate body header")
    func iPhoneEntryDetailUsesEntryTitleAsNavigationTitleWithoutDuplicateBodyHeader() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)
        let padSections = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let macWorkspace = try String(
            contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"),
            encoding: .utf8
        )

        #expect(supportingViews.contains("enum EntryDetailTitlePresentation"))
        #expect(supportingViews.contains("case objectNavigationTitle"))
        #expect(supportingViews.contains("case embeddedHeader"))
        #expect(supportingViews.contains("private var entryNavigationTitle: String"))
        #expect(supportingViews.contains("entry.title.trimmingCharacters(in: .whitespacesAndNewlines)"))
        #expect(supportingViews.contains(#"localizedString("entryDetail.title")"#))
        #expect(supportingViews.contains("titlePresentation.usesObjectNavigationTitle"))
        #expect(supportingViews.contains("titlePresentation.showsInlineHeader"))
        #expect(supportingViews.contains("if titlePresentation.showsInlineHeader"))
        #expect(supportingViews.contains("EntryDetailHeader(entry: entry)"))
        #expect(!supportingViews.contains(#".navigationTitle(localizedText("entryDetail.title"))"#))
        #expect(!supportingViews.contains("@State private var entryNavigationTitle"))
        #expect(phoneMainView.contains("titlePresentation: .objectNavigationTitle"))
        #expect(padSections.contains("titlePresentation: .embeddedHeader"))
        #expect(macWorkspace.contains("titlePresentation: .embeddedHeader"))
    }

    @Test("Entry detail does not show informational practice candidate cards on any platform")
    func entryDetailDoesNotShowInformationalPracticeCandidateCardsOnAnyPlatform() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )

        #expect(supportingViews.contains("SentencePairView("))
        #expect(supportingViews.contains("onPracticeSentence(rendering, sentence, index)"))
        #expect(!supportingViews.contains(#"SectionHeader(titleKey: "entryDetail.practiceEntry.title")"#))
        #expect(!supportingViews.contains("CompactPanel(title: item.title, text: item.summary"))
        #expect(!supportingViews.contains(#"localizedTitleKey: "practice.noContent.title""#))
    }

    @Test("three platform detail routes own real generation and analysis actions")
    func threePlatformDetailRoutesOwnRealGenerationAndAnalysisActions() throws {
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

        #expect(phoneMainView.contains("EntryDetailStoreView("))
        #expect(supportingViews.contains("onGenerateLearningMaterial"))
        #expect(supportingViews.contains("contentStore.generateLearningMaterial"))
        #expect(supportingViews.contains("entry.rendering.generateLearningMaterial.title"))
        #expect(supportingViews.contains("entry.rendering.generateLearningMaterial.summary"))
        #expect(supportingViews.contains("onCancelLearningMaterialGeneration"))
        #expect(supportingViews.contains("contentStore.cancelLearningMaterialGeneration"))
        #expect(supportingViews.contains("onUpdateLearningText"))
        #expect(supportingViews.contains("contentStore.updateLearningText"))
        #expect(supportingViews.contains("onAnalyzeCurrentLearningText"))
        #expect(supportingViews.contains("contentStore.analyzeCurrentLearningText"))
        #expect(padSections.contains("EntryDetailStoreView("))
        #expect(macWorkspace.contains("EntryDetailStoreView("))
    }

    @Test("iPhone detail supports editable learning text and reanalysis")
    func iPhoneDetailSupportsEditableLearningTextAndReanalysis() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)

        #expect(supportingViews.contains("LearningMaterialEditorView"))
        #expect(supportingViews.contains("TextEditor(text: $draftText)"))
        #expect(supportingViews.contains("entry.rendering.learningText.save"))
        #expect(supportingViews.contains("entry.rendering.learningText.reanalyze"))
        #expect(supportingViews.contains("entry.rendering.learningText.analyzing"))
        #expect(supportingViews.contains("entry.rendering.learningText.analysisFailed"))
        #expect(phoneMainView.contains("EntryDetailStoreView("))
        #expect(supportingViews.contains("contentStore.updateLearningText"))
        #expect(supportingViews.contains("contentStore.analyzeCurrentLearningText"))
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
        #expect(!supportingViews.contains("private struct EntryTextEditorSurface"))
        #expect(supportingViews.contains("EntryDetailPhotoLayout.loadedCard"))
        #expect(!supportingViews.contains("navigationTitle(sheetTitle)"))
        #expect(supportingViews.contains("@State private var isEditorPresented = false"))
        #expect(supportingViews.contains(".sheet(isPresented: $isEditorPresented)"))
        #expect(!supportingViews.contains(".presentationDetents([.large])"))
        #expect(supportingViews.contains("EntryTextEditorSheetSizing"))
        #expect(supportingViews.contains(
            ".presentationDetents(EntryTextEditorSheetSizing.detents, selection: $selectedDetent)"
        ))
        #expect(supportingViews.contains("entry.rendering.learningText.edit"))
        #expect(supportingViews.contains(".langoPanel(padding: 14)"))
        #expect(phoneMainView.contains("EntryDetailStoreView("))
        #expect(supportingViews.contains("contentStore.updateEntryBody"))
        #expect(supportingViews.contains("contentStore.sourceEntryIsStale"))
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

    @Test("entry text editor sheet chooses compact initial height only for short text")
    func entryTextEditorSheetChoosesCompactInitialHeightOnlyForShortText() {
        #expect(EntryTextEditorSheetSizing.preference(for: "Today I wrote one sentence.") == .compact)
        #expect(EntryTextEditorSheetSizing.preference(for: "Line 1\nLine 2\nLine 3") == .compact)

        let longSingleParagraph = String(repeating: "A", count: 121)
        #expect(EntryTextEditorSheetSizing.preference(for: longSingleParagraph) == .large)
        #expect(EntryTextEditorSheetSizing.preference(for: "Line 1\nLine 2\nLine 3\nLine 4") == .large)
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

        #expect(components.contains("let playbackState: SentenceAudioPresentationState"))
        #expect(components.contains("onListen: onListen"))
        #expect(!components.contains("isLocalPlaybackActive.toggle()"))
        #expect(!components.contains("LocalListeningPreviewView"))
        #expect(!components.contains(".sheet(isPresented: $isListeningPreviewPresented)"))
        #expect(!components.contains("isListeningPreviewPresented"))
        #expect(controls.contains("let playbackState: SentenceAudioPresentationState"))
        #expect(controls.contains("playbackState.listenButtonSystemImage"))
        #expect(controls.contains("playbackState.listenButtonTitleKey"))
        #expect(!components.contains("UnavailableCapabilityView(content: ." + "listenOne)"))
    }

    @Test("Practice session keeps inline navigation title during playback state updates")
    func practiceSessionKeepsInlineNavigationTitleDuringPlaybackUpdates() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PracticeSessionViews.swift"), encoding: .utf8)

        #expect(source.contains("PracticeSessionView"))
        #expect(source.contains(".navigationTitle(localizedText(\"practice.title\"))"))
        #expect(source.contains(".langoPracticeInlineNavigationTitle()"))
        #expect(source.contains("navigationBarTitleDisplayMode(.inline)"))
        #expect(source.contains("#if os(iOS)"))
    }

    @Test("Practice prompt disclosures reset when route identity changes")
    func practicePromptDisclosuresResetWhenRouteIdentityChanges() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PracticeSessionViews.swift"), encoding: .utf8)
        let promptCard = try String(contentsOf: sourceFileURL(named: "PracticePromptCard.swift"), encoding: .utf8)

        #expect(source.contains("@State private var isTranslationExpanded = false"))
        #expect(source.contains("@State private var isExplanationExpanded = false"))
        #expect(source.contains("private func resetPromptDisclosures()"))
        #expect(source.contains(".onChange(of: routeSeed.practiceRouteIdentity)"))
        #expect(source.contains("resetPromptDisclosures()"))
        #expect(source.contains("PracticePromptCard("))
        #expect(promptCard.contains("displayedTranslationText"))
        #expect(promptCard.contains("private var disclosureControls"))
        #expect(promptCard.contains("ViewThatFits(in: .horizontal)"))
        #expect(promptCard.contains("HStack(alignment: .center, spacing: 16)"))
        #expect(promptCard.contains("explanationParagraphs"))
        #expect(promptCard.contains("VStack(alignment: .leading, spacing: 8)"))
        #expect(!promptCard.contains("practice.prompt.translation.title"))
        #expect(!promptCard.contains("PracticePromptCardLayout.collapsedMinHeight"))
        #expect(!promptCard.contains(".frame(minHeight: PracticePromptCardLayout.collapsedMinHeight"))
        #expect(promptCard.contains("practice.prompt.translation.toggle.hint"))
        #expect(promptCard.contains("practice.prompt.explanation.toggle.hint"))
        #expect(!source.contains("PracticeSnapshotPanel("))
    }

    @Test("Shadowing session uses a centered stage with a bottom-docked control deck")
    func shadowingSessionUsesCenteredStageWithBottomDockedControlDeck() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PracticeSessionViews.swift"), encoding: .utf8)
        let promptCard = try String(contentsOf: sourceFileURL(named: "PracticePromptCard.swift"), encoding: .utf8)
        let controlBar = try String(contentsOf: sourceFileURL(named: "PracticeControlBar.swift"), encoding: .utf8)

        // Stage + deck layout intent is resolved through the testable layout model.
        #expect(source.contains("PracticeShadowingLayout.resolve("))
        #expect(source.contains(".safeAreaInset(edge: .bottom"))
        #expect(source.contains("PracticeControlDeckHeightKey"))
        #expect(source.contains("private func controlDeck(session: PracticeSession)"))
        #expect(source.contains("isCentered: true"))
        // Control bar stays above the in-record navigation (spec 003 keeps navigation after the action card).
        #expect(source.contains("PracticeControlBar("))
        #expect(source.contains("PracticeSentenceNavigationBar("))
        // The prompt card gained an opt-in centered emphasis without losing disclosure structure.
        #expect(promptCard.contains("var isCentered: Bool"))
        #expect(promptCard.contains("multilineTextAlignment(multilineAlignment)"))
        // The control bar sits directly on the deck surface: no inner panel chrome (no box-in-card),
        // but keeps a stroke-free vertical inset so the primary button stays clear of the navigation bar.
        #expect(!controlBar.contains(".langoPanel("))
        #expect(controlBar.contains(".padding(.vertical, 14)"))
    }

    @Test("iPad and Mac practice shells match the iOS repeatable recording flow")
    func iPadAndMacPracticeShellsMatchIOSRepeatableRecordingFlow() throws {
        let padLearningPanel = try String(
            contentsOf: sourceFileURL(named: "PadLearningPanelView.swift"),
            encoding: .utf8
        )
        let macWorkspace = try String(
            contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"),
            encoding: .utf8
        )
        let macModels = try String(contentsOf: sourceFileURL(named: "MacMainModels.swift"), encoding: .utf8)

        #expect(padLearningPanel.contains("status: hasPracticeItems ? .ready : .unavailable"))
        #expect(!padLearningPanel.contains("status: hasPracticeItems ? .mockOnly : .unavailable"))
        #expect(macWorkspace.contains("status: .ready"))
        #expect(!macWorkspace.contains("status: .mockOnly,\n                systemImage: \"waveform\""))
        #expect(macWorkspace.contains("PracticeSentenceListView("))
        #expect(macWorkspace.contains("PracticeSessionView("))
        #expect(macWorkspace.contains("onRoute(.practiceSentence(nextSeed))"))
        #expect(macModels.contains(".practiceSentenceList, .practiceSentence, .languageSpaceManagement"))
    }

    @Test("Sentence audio playback state is observed by the visible detail route")
    func sentenceAudioPlaybackStateIsSwiftUIObservedDetailInput() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let phoneMainView = try String(
            contentsOf: sourceFileURL(named: "PhoneMainView.swift"),
            encoding: .utf8
        )
        let padSections = try String(
            contentsOf: sourceFileURL(named: "PadMainSections.swift"),
            encoding: .utf8
        )
        let macWorkspace = try String(
            contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"),
            encoding: .utf8
        )

        #expect(
            supportingViews.contains(
                "var sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState] = [:]"
            )
        )
        #expect(supportingViews.contains("playbackState: sentenceAudioPlaybackStates[sentence.id] ?? .idle"))
        #expect(
            !supportingViews.contains(
                "var sentenceAudioPlaybackState: (String) -> SentenceAudioPresentationState"
            )
        )
        #expect(supportingViews.contains("struct EntryDetailStoreView: View"))
        #expect(supportingViews.contains("@ObservedObject var contentStore: LearningContentStore"))
        #expect(supportingViews.contains("sentenceAudioPlaybackStates: contentStore.sentenceAudioPlaybackStates"))
        #expect(phoneMainView.contains("EntryDetailStoreView("))
        #expect(!phoneMainView.contains("sentenceAudioPlaybackStates: contentStore.sentenceAudioPlaybackStates"))
        #expect(padSections.contains("@ObservedObject var contentStore: LearningContentStore"))
        #expect(padSections.contains("EntryDetailStoreView("))
        #expect(!padSections.contains("sentenceAudioPlaybackStates: contentStore.sentenceAudioPlaybackStates"))
        #expect(macWorkspace.contains("@ObservedObject var contentStore: LearningContentStore"))
        #expect(macWorkspace.contains("EntryDetailStoreView("))
        #expect(!macWorkspace.contains("sentenceAudioPlaybackStates: contentStore.sentenceAudioPlaybackStates"))
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
