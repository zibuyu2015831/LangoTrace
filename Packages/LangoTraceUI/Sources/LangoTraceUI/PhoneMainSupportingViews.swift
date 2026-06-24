import LangoTraceCore
import LangoTraceData
import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let languageSpace: LanguageSpacePreview
    let onSave: (String, String) throws -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var saveErrorKey: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        text: $title,
                        prompt: localizedText("entryEditor.titleField")
                    ) {
                        localizedText("entryEditor.titleField")
                    }
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 180)
                        .accessibilityLabel(localizedText("entryEditor.bodyField.accessibilityLabel"))
                        .accessibilityHint(localizedText("entryEditor.bodyField.accessibilityHint"))
                } header: {
                    localizedText("entryEditor.section.content")
                } footer: {
                    if let saveErrorKey {
                        localizedText(saveErrorKey)
                            .font(.footnote)
                            .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
                    }
                }
                Section {
                    Label {
                        localizedText("entryEditor.privacy.localOnly")
                    } icon: {
                        Image(systemName: "lock")
                    }
                } header: {
                    localizedText("entryEditor.section.privacy")
                }
            }
            .scrollContentBackground(.hidden)
            .langoPageBackground()
            .navigationTitle(localizedText("entryEditor.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        localizedText("common.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        do {
                            try onSave(title, bodyText)
                            saveErrorKey = nil
                            dismiss()
                        } catch {
                            // Keep the draft on screen and surface the failure instead of dismissing.
                            saveErrorKey = "entryEditor.saveFailed"
                        }
                    } label: {
                        localizedText("common.save")
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum EntryDetailTitlePresentation {
    case objectNavigationTitle
    case embeddedHeader

    var showsInlineHeader: Bool {
        self == .embeddedHeader
    }

    var usesObjectNavigationTitle: Bool {
        self == .objectNavigationTitle
    }
}

struct EntryDetailView: View {
    let languageSpace: LanguageSpacePreview
    let entry: LearningEntry
    let rendering: LearningRendering?
    let titlePresentation: EntryDetailTitlePresentation
    var generationState: LearningMaterialGenerationState = .idle
    var sourceEntryIsStale: Bool = false
    var onGenerateLearningMaterial: (() -> Void)?
    var onCancelLearningMaterialGeneration: (() -> Void)?
    var onUpdateEntryBody: ((String) throws -> Void)?
    var onUpdateLearningText: ((String, String) -> Void)?
    var onAnalyzeCurrentLearningText: (() -> Void)?
    var sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState] = [:]
    var onListenSentence: ((LearningRendering, RenderingSentence, Int) -> Void)?
    let onGenerateLocalPreview: () -> Void
    let onPracticeSentence: (LearningRendering, RenderingSentence, Int) -> Void
    var onOpenReading: (() -> Void)?

    @Environment(\.photoDisplayActions) private var photoDisplayActions
    @State private var photoImage: Image?
    @State private var photoPresentation: EntryDetailPhotoPresentation = .notApplicable

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if titlePresentation.showsInlineHeader {
                    EntryDetailHeader(entry: entry)
                }
                let currentPhotoPresentation = displayedPhotoPresentation
                if currentPhotoPresentation.shouldRenderRegion {
                    EntryDetailPhotoSection(
                        presentation: currentPhotoPresentation,
                        photoImage: photoImage
                    )
                }
                SourceEntryTextView(
                    entry: entry,
                    nativeLanguageName: languageSpace.nativeLanguage,
                    onSave: onUpdateEntryBody
                )
                if let rendering {
                    if let onUpdateLearningText, let onAnalyzeCurrentLearningText {
                        LearningMaterialEditorView(
                            rendering: rendering,
                            generationState: generationState,
                            targetLanguageName: languageSpace.targetLanguage,
                            sourceEntryIsStale: sourceEntryIsStale,
                            onSave: { learningText in
                                onUpdateLearningText(rendering.id, learningText)
                            },
                            onReanalyze: onAnalyzeCurrentLearningText,
                            onRegenerate: onGenerateLearningMaterial,
                            onOpenReading: onOpenReading
                        )
                    } else {
                        EntryDetailTextCard(
                            title: targetTextTitle,
                            text: rendering.targetText,
                            textEmphasis: .primary,
                            statusKey: sourceEntryIsStale ? "entry.detail.learningText.sourceStale" : nil,
                            accessibilityLabelKey: "entry.rendering.learningText.accessibilityLabel"
                        )
                    }
                    SectionHeader(titleKey: "entryDetail.sentences.title")
                    ForEach(Array(rendering.sentences.enumerated()), id: \.element.id) { index, sentence in
                        SentencePairView(
                            index: index + 1,
                            sentence: sentence,
                            playbackState: sentenceAudioPlaybackStates[sentence.id] ?? .idle,
                            onListen: {
                                onListenSentence?(rendering, sentence, index)
                            },
                            onPractice: {
                                onPracticeSentence(rendering, sentence, index)
                            }
                        )
                    }
                } else if let onGenerateLearningMaterial {
                    EntryDetailTextCard(
                        title: targetTextTitle,
                        text: localizedString("entry.rendering.pending"),
                        textEmphasis: .secondary,
                        accessibilityLabelKey: "entry.rendering.learningText.accessibilityLabel"
                    )
                    CapabilityStatusRow(
                        localizedTitleKey: generationTitleKey,
                        localizedSummaryKey: generationSummaryKey,
                        status: generationStatus,
                        systemImage: "sparkles",
                        action: generationState.isRunning
                            ? onCancelLearningMaterialGeneration
                            : onGenerateLearningMaterial
                    )
                } else {
                    EntryDetailTextCard(
                        title: targetTextTitle,
                        text: localizedString("entry.rendering.pending"),
                        textEmphasis: .secondary,
                        accessibilityLabelKey: "entry.rendering.learningText.accessibilityLabel"
                    )
                    CapabilityStatusRow(
                        localizedTitleKey: "entry.rendering.localPreview.title",
                        localizedSummaryKey: "entry.rendering.localPreview.summary",
                        status: .mockOnly,
                        systemImage: "sparkles",
                        action: onGenerateLocalPreview
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle(
            titlePresentation.usesObjectNavigationTitle
                ? entryNavigationTitle
                : localizedString("entryDetail.title")
        )
        .langoPageBackground()
        .task(id: entry.id) {
            photoImage = nil
            photoPresentation = EntryDetailPhotoPresentation.initialState(for: entry)
            guard entry.source == .photoWriting else { return }
            guard let data = await photoDisplayActions.loadPhotoData(entry.id) else {
                photoPresentation = .unavailable
                return
            }
            #if os(iOS)
                if let uiImage = UIImage(data: data) {
                    photoImage = Image(uiImage: uiImage)
                    photoPresentation = .loaded
                } else {
                    photoPresentation = .failed
                }
            #elseif os(macOS)
                if let nsImage = NSImage(data: data) {
                    photoImage = Image(nsImage: nsImage)
                    photoPresentation = .loaded
                } else {
                    photoPresentation = .failed
                }
            #else
                photoPresentation = .failed
            #endif
        }
    }

    private var displayedPhotoPresentation: EntryDetailPhotoPresentation {
        if photoPresentation == .notApplicable {
            EntryDetailPhotoPresentation.initialState(for: entry)
        } else {
            photoPresentation
        }
    }

    private var generationTitleKey: String {
        switch generationState {
        case .generating:
            "entry.rendering.generateLearningMaterial.generatingTitle"
        default:
            "entry.rendering.generateLearningMaterial.title"
        }
    }

    private var generationSummaryKey: String {
        switch generationState {
        case .generating:
            "entry.rendering.generateLearningMaterial.generatingSummary"
        case .blocked(.contentTooLong):
            "entry.rendering.generateLearningMaterial.tooLongSummary"
        case let .failed(display):
            switch display.category {
            case .authenticationFailed:
                "entry.rendering.generateLearningMaterial.failedSummary.authFailed"
            case .networkUnavailable, .timeout:
                "entry.rendering.generateLearningMaterial.failedSummary.networkError"
            case .rateLimited:
                "entry.rendering.generateLearningMaterial.failedSummary.rateLimited"
            case .unsupportedModel, .invalidStructuredResponse:
                "entry.rendering.generateLearningMaterial.failedSummary.responseError"
            default:
                "entry.rendering.generateLearningMaterial.failedSummary"
            }
        default:
            "entry.rendering.generateLearningMaterial.summary"
        }
    }

    private var generationStatus: CapabilityStatus {
        switch generationState {
        case .blocked(.contentTooLong), .blocked(.contentEmpty):
            .unavailable
        case let .failed(display):
            switch display.category {
            case .providerNotConfigured, .credentialMissing, .unsupportedProvider:
                .unavailable
            default:
                .ready
            }
        case .idle, .generated, .editing, .cancelled, .generating, .analyzing, .blocked:
            .ready
        }
    }

    private var targetTextTitle: String {
        let trimmed = languageSpace.targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return localizedString("entry.detail.learningText.fallbackTitle")
        }
        return localizedString("entry.detail.learningText.titleFormat", trimmed)
    }

    private var entryNavigationTitle: String {
        let trimmed = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return localizedString("entryDetail.title")
        }
        return trimmed
    }
}

private struct EntryDetailPhotoSection: View {
    let presentation: EntryDetailPhotoPresentation
    let photoImage: Image?
    private let layout = EntryDetailPhotoLayout.loadedCard

    var body: some View {
        Group {
            if presentation == .loaded, let photoImage {
                loadedPhoto(photoImage)
            } else {
                photoStatus
            }
        }
        .frame(maxWidth: .infinity)
        .background(LangoTraceDesign.ColorToken.elevatedPaper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if layout.hasVisibleChrome {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.borderSubtle, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func loadedPhoto(_ image: Image) -> some View {
        switch layout.imageSizing {
        case .fit:
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: layout.maximumImageHeight)
                .padding(8)
                .accessibilityLabel(localizedString("photoWriting.photo.accessibilityLabel"))
        }
    }

    private var photoStatus: some View {
        VStack(spacing: 10) {
            if presentation == .loading {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            if let titleKey = presentation.titleKey {
                localizedText(titleKey)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            }
            if let summaryKey = presentation.summaryKey {
                localizedText(summaryKey)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220)
        .accessibilityElement(children: .combine)
    }
}

struct EntryDetailStoreView: View {
    let languageSpace: LanguageSpacePreview
    let entryID: String
    @ObservedObject var contentStore: LearningContentStore
    let titlePresentation: EntryDetailTitlePresentation
    let onPracticeSentence: (PracticeSessionRouteSeed) -> Void
    var onOpenReading: ((String) -> Void)?

    var body: some View {
        if let entry = contentStore.entry(id: entryID) {
            EntryDetailView(
                languageSpace: languageSpace,
                entry: entry,
                rendering: contentStore.rendering(for: entry),
                titlePresentation: titlePresentation,
                generationState: contentStore.generationState(for: entry),
                sourceEntryIsStale: contentStore.sourceEntryIsStale(for: entry),
                onGenerateLearningMaterial: {
                    Task {
                        await contentStore.generateLearningMaterial(
                            for: entry,
                            languageSpace: languageSpace
                        )
                    }
                },
                onCancelLearningMaterialGeneration: {
                    Task {
                        await contentStore.cancelLearningMaterialGeneration(for: entry)
                    }
                },
                onUpdateEntryBody: { body in
                    try contentStore.updateEntryBody(entryID: entry.id, body: body)
                },
                onUpdateLearningText: { materialID, learningText in
                    Task {
                        await contentStore.updateLearningText(
                            materialID: materialID,
                            entryID: entry.id,
                            learningText: learningText
                        )
                    }
                },
                onAnalyzeCurrentLearningText: {
                    Task {
                        await contentStore.analyzeCurrentLearningText(
                            for: entry,
                            languageSpace: languageSpace
                        )
                    }
                },
                sentenceAudioPlaybackStates: contentStore.sentenceAudioPlaybackStates,
                onListenSentence: { rendering, sentence, index in
                    Task {
                        await contentStore.handleSentenceAudioTap(
                            rendering: rendering,
                            sentence: sentence,
                            sentenceIndex: index,
                            languageSpace: languageSpace
                        )
                    }
                },
                onGenerateLocalPreview: { contentStore.generateLocalPreview(for: entry) },
                onPracticeSentence: { rendering, sentence, index in
                    onPracticeSentence(
                        PracticeSessionRouteSeed(
                            entry: entry,
                            rendering: rendering,
                            sentence: sentence,
                            sentenceIndex: index,
                            targetLanguageCode: languageSpace.targetLanguageCode,
                            capturedAt: Date()
                        )
                    )
                },
                onOpenReading: onOpenReading.map { handler in { handler(entry.id) } }
            )
        }
    }
}

private struct SourceEntryTextView: View {
    let entry: LearningEntry
    let nativeLanguageName: String
    let onSave: ((String) throws -> Void)?

    @State private var draftText: String
    @State private var isEditorPresented = false
    @State private var saveErrorKey: String?

    init(
        entry: LearningEntry,
        nativeLanguageName: String,
        onSave: ((String) throws -> Void)?
    ) {
        self.entry = entry
        self.nativeLanguageName = nativeLanguageName
        self.onSave = onSave
        _draftText = State(initialValue: entry.body)
    }

    var body: some View {
        EntryDetailTextCard(
            title: sourceTextTitle,
            text: entry.body,
            textEmphasis: .secondary,
            statusKey: nil,
            accessibilityLabelKey: "entry.detail.sourceText.accessibilityLabel",
            collapse: EntrySourceCollapsePresentation.make(for: entry.body)
        ) {
            if onSave != nil {
                Button {
                    draftText = entry.body
                    saveErrorKey = nil
                    isEditorPresented = true
                } label: {
                    Image(systemName: "pencil")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .accessibilityLabel(localizedText("entry.detail.sourceText.edit"))
            }
        }
        .onChange(of: entry.body) {
            draftText = entry.body
        }
        .sheet(isPresented: $isEditorPresented) {
            SourceEntryEditorSheet(
                draftText: $draftText,
                canSave: sourceCanSave,
                saveErrorKey: saveErrorKey,
                onCancel: {
                    draftText = entry.body
                    saveErrorKey = nil
                    isEditorPresented = false
                },
                onSave: {
                    do {
                        try onSave?(draftText)
                        saveErrorKey = nil
                        isEditorPresented = false
                    } catch {
                        saveErrorKey = "entry.detail.sourceText.saveFailed"
                    }
                }
            )
        }
    }

    private var sourceCanSave: Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != entry.body
    }

    private var sourceTextTitle: String {
        let trimmed = nativeLanguageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return localizedString("entry.detail.sourceText.fallbackTitle")
        }
        return localizedString("entry.detail.sourceText.titleFormat", trimmed)
    }
}

private struct LearningMaterialEditorView: View {
    let rendering: LearningRendering
    let generationState: LearningMaterialGenerationState
    let targetLanguageName: String
    let sourceEntryIsStale: Bool
    let onSave: (String) -> Void
    let onReanalyze: () -> Void
    let onRegenerate: (() -> Void)?
    let onOpenReading: (() -> Void)?

    @State private var draftText: String
    @State private var isEditorPresented = false
    @State private var pendingRegeneration: PendingLearningRegeneration?

    private enum PendingLearningRegeneration: Identifiable {
        case translate
        case reanalyze

        var id: String {
            switch self {
            case .translate: "translate"
            case .reanalyze: "reanalyze"
            }
        }
    }

    init(
        rendering: LearningRendering,
        generationState: LearningMaterialGenerationState,
        targetLanguageName: String,
        sourceEntryIsStale: Bool,
        onSave: @escaping (String) -> Void,
        onReanalyze: @escaping () -> Void,
        onRegenerate: (() -> Void)?,
        onOpenReading: (() -> Void)?
    ) {
        self.rendering = rendering
        self.generationState = generationState
        self.targetLanguageName = targetLanguageName
        self.sourceEntryIsStale = sourceEntryIsStale
        self.onSave = onSave
        self.onReanalyze = onReanalyze
        self.onRegenerate = onRegenerate
        self.onOpenReading = onOpenReading
        _draftText = State(initialValue: rendering.targetText)
    }

    var body: some View {
        EntryDetailTextCard(
            title: title,
            text: rendering.targetText,
            textEmphasis: .primary,
            statusKey: statusKey,
            accessibilityLabelKey: "entry.rendering.learningText.accessibilityLabel",
            collapse: EntrySourceCollapsePresentation.make(for: rendering.targetText)
        ) {
            if let onOpenReading {
                Button(action: onOpenReading) {
                    Image(systemName: "book")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .accessibilityLabel(localizedText("entry.reading.open"))
            }
            Menu {
                Button {
                    pendingRegeneration = .translate
                } label: {
                    Label(
                        localizedString("entry.detail.learningText.regenerateMenu.translate"),
                        systemImage: "character.book.closed"
                    )
                }
                .disabled(!(availability.canRegenerate && onRegenerate != nil))
                Button {
                    pendingRegeneration = .reanalyze
                } label: {
                    Label(
                        localizedString("entry.detail.learningText.regenerateMenu.reanalyze"),
                        systemImage: "text.magnifyingglass"
                    )
                }
                .disabled(!availability.canReanalyze)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .menuIndicator(.hidden)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .disabled(!(availability.canRegenerate || availability.canReanalyze))
            .accessibilityLabel(localizedText("entry.detail.learningText.regenerateMenu"))
            Button {
                draftText = rendering.targetText
                isEditorPresented = true
            } label: {
                Image(systemName: "pencil")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .disabled(!availability.canEdit)
            .accessibilityLabel(localizedText("entry.rendering.learningText.edit"))
        }
        .confirmationDialog(
            localizedText("entry.detail.learningText.regenerate.confirmTitle"),
            isPresented: regenerationConfirmationBinding,
            titleVisibility: .visible,
            presenting: pendingRegeneration
        ) { pending in
            Button(localizedString("entry.detail.learningText.regenerate.confirm"), role: .destructive) {
                switch pending {
                case .translate: onRegenerate?()
                case .reanalyze: onReanalyze()
                }
                pendingRegeneration = nil
            }
            Button(localizedString("common.cancel"), role: .cancel) {
                pendingRegeneration = nil
            }
        } message: { _ in
            localizedText("entry.detail.learningText.regenerate.confirmMessage")
        }
        .onChange(of: rendering.targetText) {
            draftText = rendering.targetText
        }
        .sheet(isPresented: $isEditorPresented) {
            LearningMaterialEditorSheet(
                draftText: $draftText,
                canSave: canSave,
                isRunning: generationState.isRunning,
                onCancel: {
                    draftText = rendering.targetText
                    isEditorPresented = false
                },
                onSave: {
                    onSave(draftText)
                    isEditorPresented = false
                }
            )
        }
    }

    private var title: String {
        let trimmed = targetLanguageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return localizedString("entry.detail.learningText.fallbackTitle")
        }
        return localizedString("entry.detail.learningText.titleFormat", trimmed)
    }

    private var statusKey: String? {
        if sourceEntryIsStale {
            return "entry.detail.learningText.sourceStale"
        }
        switch generationState {
        case .analyzing:
            return "entry.rendering.learningText.analyzing"
        case .failed:
            return "entry.rendering.learningText.analysisFailed"
        default:
            return generationState.analysisIsStale ? "entry.rendering.learningText.stale" : nil
        }
    }

    private var canSave: Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != rendering.targetText && !generationState.isRunning
    }

    private var availability: LearningMaterialActionAvailability {
        LearningMaterialActionAvailability.make(
            generationState: generationState,
            sourceEntryIsStale: sourceEntryIsStale
        )
    }

    private var regenerationConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingRegeneration != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRegeneration = nil
                }
            }
        )
    }
}

private struct EntryDetailTextCard<ActionContent: View>: View {
    enum Emphasis {
        case primary
        case secondary
    }

    let title: String
    let text: String
    let textEmphasis: Emphasis
    var statusKey: String?
    var accessibilityLabelKey: String
    /// When non-nil and `isExpandable`, the body text collapses to `collapsedLineLimit`
    /// lines with an inline expand/collapse control (line-based so Dynamic Type is
    /// respected). When nil the text renders in full, preserving prior behavior.
    var collapse: EntrySourceCollapsePresentation?
    @ViewBuilder var actions: () -> ActionContent

    @State private var isExpanded = false

    private var isCollapsible: Bool {
        collapse?.isExpandable ?? false
    }

    private var showingCollapsed: Bool {
        isCollapsible && !isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    if let statusKey {
                        localizedText(statusKey)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(statusColor)
                    }
                }
                .frame(minHeight: 44, alignment: .center)
                Spacer(minLength: 12)
                HStack(spacing: 8) {
                    actions()
                }
                .frame(minHeight: 44, alignment: .center)
            }
            bodyText
            if isCollapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    localizedText(isExpanded ? "entry.detail.collapse" : "entry.detail.expand")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .langoPanel(padding: 14)
    }

    @ViewBuilder
    private var bodyText: some View {
        let text = Text(text)
            .font(textEmphasis == .primary ? .body.weight(.medium) : .body)
            .lineSpacing(4)
            .foregroundStyle(textColor)
        if showingCollapsed {
            text
                .lineLimit(collapse?.collapsedLineLimit)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .accessibilityLabel(localizedText(accessibilityLabelKey))
        } else {
            text
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .accessibilityLabel(localizedText(accessibilityLabelKey))
        }
    }

    private var textColor: Color {
        switch textEmphasis {
        case .primary:
            LangoTraceDesign.ColorToken.textPrimary
        case .secondary:
            LangoTraceDesign.ColorToken.textSecondary
        }
    }

    private var statusColor: Color {
        statusKey == "entry.detail.learningText.sourceStale"
            ? LangoTraceDesign.ColorToken.stateWarning
            : LangoTraceDesign.ColorToken.textSecondary
    }
}

private extension EntryDetailTextCard where ActionContent == EmptyView {
    init(
        title: String,
        text: String,
        textEmphasis: Emphasis,
        statusKey: String? = nil,
        accessibilityLabelKey: String,
        collapse: EntrySourceCollapsePresentation? = nil
    ) {
        self.title = title
        self.text = text
        self.textEmphasis = textEmphasis
        self.statusKey = statusKey
        self.accessibilityLabelKey = accessibilityLabelKey
        self.collapse = collapse
        actions = { EmptyView() }
    }
}

enum EntryTextEditorSheetSizing: Equatable {
    case compact
    case large

    static let detents: Set<PresentationDetent> = [.fraction(0.42), .large]

    static func preference(for text: String) -> EntryTextEditorSheetSizing {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lineCount = max(1, trimmed.components(separatedBy: .newlines).count)

        if trimmed.count <= 120, lineCount <= 3 {
            return .compact
        }
        return .large
    }

    var presentationDetent: PresentationDetent {
        switch self {
        case .compact:
            .fraction(0.42)
        case .large:
            .large
        }
    }
}

private struct SourceEntryEditorSheet: View {
    @Binding var draftText: String

    let canSave: Bool
    let saveErrorKey: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var selectedDetent: PresentationDetent

    init(
        draftText: Binding<String>,
        canSave: Bool,
        saveErrorKey: String?,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        _draftText = draftText
        self.canSave = canSave
        self.saveErrorKey = saveErrorKey
        self.onCancel = onCancel
        self.onSave = onSave
        _selectedDetent = State(
            initialValue: EntryTextEditorSheetSizing.preference(for: draftText.wrappedValue).presentationDetent
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $draftText)
                    .font(.body)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(20)
                    .background(LangoTraceDesign.ColorToken.surfaceBase)
                    .accessibilityLabel(localizedText("entry.detail.sourceText.accessibilityLabel"))
                if let saveErrorKey {
                    localizedText(saveErrorKey)
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        localizedText("common.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        localizedText("common.save")
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents(EntryTextEditorSheetSizing.detents, selection: $selectedDetent)
    }
}

private struct LearningMaterialEditorSheet: View {
    @Binding var draftText: String

    let canSave: Bool
    let isRunning: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var selectedDetent: PresentationDetent

    init(
        draftText: Binding<String>,
        canSave: Bool,
        isRunning: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        _draftText = draftText
        self.canSave = canSave
        self.isRunning = isRunning
        self.onCancel = onCancel
        self.onSave = onSave
        _selectedDetent = State(
            initialValue: EntryTextEditorSheetSizing.preference(for: draftText.wrappedValue).presentationDetent
        )
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $draftText)
                .font(.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .padding(20)
                .background(LangoTraceDesign.ColorToken.surfaceBase)
                .accessibilityLabel(localizedText("entry.rendering.learningText.accessibilityLabel"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onCancel) {
                            localizedText("common.cancel")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: onSave) {
                            localizedText("entry.rendering.learningText.save")
                        }
                        .disabled(!canSave || isRunning)
                    }
                }
        }
        .presentationDetents(EntryTextEditorSheetSizing.detents, selection: $selectedDetent)
    }
}

struct HeroActionCard: View {
    let languageSpace: LanguageSpacePreview
    let onNewEntry: () -> Void
    let onPhotoWriting: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                localizedText("hero.title")
                    .font(.system(.title2, design: .default, weight: .semibold))
                heroSubtitle
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onNewEntry) {
                Label {
                    localizedText("common.writeSentence")
                } icon: {
                    Image(systemName: "pencil")
                }
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.primaryActionFill)

            SecondaryActionChip(titleKey: "photoWriting.startWithPhoto", systemImage: "camera", action: onPhotoWriting)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 20)
        .langoSoftShadow()
    }

    private var heroSubtitle: Text {
        Text(localizedString("hero.subtitle", languageSpace.targetLanguage))
    }
}

struct EntryCard: View {
    let entry: LearningEntry
    let targetLanguage: String
    let rendering: LearningRendering?
    let action: () -> Void

    @Environment(\.photoDisplayActions) private var photoDisplayActions
    @State private var thumbnailImage: Image?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headline)
                        Text("\(entry.displaySourceTitle) · \(targetLanguage) · \(entry.scene)")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        EntryMaterialStatusPill(entry: entry, rendering: rendering)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Text(entry.body)
                        .font(.body)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let thumbnailImage {
                        thumbnailImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                if let rendering {
                    Divider()
                    Text(rendering.targetText)
                        .font(.callout.weight(.medium))
                        .lineSpacing(3)
                        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .langoPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("entryCard.openDetail.label", entry.title))
        .task(id: entry.id) {
            guard entry.source == .photoWriting else { return }
            guard let data = await photoDisplayActions.loadPhotoData(entry.id) else { return }
            #if os(iOS)
                if let uiImage = UIImage(data: data) {
                    thumbnailImage = Image(uiImage: uiImage)
                }
            #elseif os(macOS)
                if let nsImage = NSImage(data: data) {
                    thumbnailImage = Image(nsImage: nsImage)
                }
            #endif
        }
    }
}

struct EmptyEntryPanel: View {
    let onNewEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                localizedText("entry.empty.title")
            } icon: {
                Image(systemName: "square.and.pencil")
            }
            .font(.headline)
            localizedText("entry.empty.body")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            Button(action: onNewEntry) {
                Label {
                    localizedText("entry.empty.action")
                } icon: {
                    Image(systemName: "plus")
                }
                .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.primaryActionFill)
        }
        .langoPanel()
    }
}

struct SectionHeader: View {
    let titleKey: String
    var subtitleKey: String?
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            localizedText(titleKey)
                .font(.headline)
            if let subtitleText {
                subtitleText
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
        .padding(.top, 4)
    }

    private var subtitleText: Text? {
        if let subtitleKey {
            return localizedText(subtitleKey)
        }

        if let subtitle, !subtitle.isEmpty {
            return Text(subtitle)
        }

        return nil
    }
}
