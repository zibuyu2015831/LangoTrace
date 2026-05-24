import LangoTraceCore
import LangoTraceData
import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let languageSpace: LanguageSpacePreview
    let onSave: (String, String) -> Void

    @State private var title = ""
    @State private var bodyText = ""

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
                        onSave(title, bodyText)
                        dismiss()
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

struct EntryDetailView: View {
    let languageSpace: LanguageSpacePreview
    let entry: LearningEntry
    let rendering: LearningRendering?
    let practiceItems: [PracticeItem]
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
    let onPractice: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EntryDetailHeader(
                    entry: entry,
                    targetLanguage: languageSpace.targetLanguage,
                    rendering: rendering
                )
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
                            onRegenerate: onGenerateLearningMaterial
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
                            onPractice: onPractice
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
                if practiceItems.isEmpty {
                    CapabilityStatusRow(
                        localizedTitleKey: "practice.noContent.title",
                        localizedSummaryKey: "practice.noContent.summary",
                        status: .unavailable,
                        systemImage: "waveform",
                        action: nil
                    )
                } else {
                    SectionHeader(titleKey: "entryDetail.practiceEntry.title")
                    ForEach(practiceItems) { item in
                        CompactPanel(title: item.title, text: item.summary, systemImage: "waveform")
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(localizedText("entryDetail.title"))
        .langoPageBackground()
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
        case .failed:
            "entry.rendering.generateLearningMaterial.failedSummary"
        default:
            "entry.rendering.generateLearningMaterial.summary"
        }
    }

    private var generationStatus: CapabilityStatus {
        switch generationState {
        case .blocked(.contentTooLong), .blocked(.contentEmpty), .failed:
            .unavailable
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
            accessibilityLabelKey: "entry.detail.sourceText.accessibilityLabel"
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

    @State private var draftText: String
    @State private var isEditorPresented = false

    init(
        rendering: LearningRendering,
        generationState: LearningMaterialGenerationState,
        targetLanguageName: String,
        sourceEntryIsStale: Bool,
        onSave: @escaping (String) -> Void,
        onReanalyze: @escaping () -> Void,
        onRegenerate: (() -> Void)?
    ) {
        self.rendering = rendering
        self.generationState = generationState
        self.targetLanguageName = targetLanguageName
        self.sourceEntryIsStale = sourceEntryIsStale
        self.onSave = onSave
        self.onReanalyze = onReanalyze
        self.onRegenerate = onRegenerate
        _draftText = State(initialValue: rendering.targetText)
    }

    var body: some View {
        EntryDetailTextCard(
            title: title,
            text: rendering.targetText,
            textEmphasis: .primary,
            statusKey: statusKey,
            accessibilityLabelKey: "entry.rendering.learningText.accessibilityLabel"
        ) {
            if sourceEntryIsStale, let onRegenerate, !generationState.isRunning {
                Button(action: onRegenerate) {
                    Image(systemName: "sparkles")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .accessibilityLabel(localizedText("entry.detail.learningText.regenerate"))
            }
            if canReanalyze {
                Button(action: onReanalyze) {
                    Image(systemName: "text.magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .accessibilityLabel(localizedText("entry.rendering.learningText.reanalyze"))
            }
            Button {
                draftText = rendering.targetText
                isEditorPresented = true
            } label: {
                Image(systemName: "pencil")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .disabled(generationState.isRunning)
            .accessibilityLabel(localizedText("entry.rendering.learningText.edit"))
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

    private var canReanalyze: Bool {
        generationState.analysisIsStale && !generationState.isRunning
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
    @ViewBuilder var actions: () -> ActionContent

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
            Text(text)
                .font(textEmphasis == .primary ? .body.weight(.medium) : .body)
                .lineSpacing(4)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .accessibilityLabel(localizedText(accessibilityLabelKey))
        }
        .langoPanel(padding: 14)
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
        accessibilityLabelKey: String
    ) {
        self.title = title
        self.text = text
        self.textEmphasis = textEmphasis
        self.statusKey = statusKey
        self.accessibilityLabelKey = accessibilityLabelKey
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

struct PracticeSessionView: View {
    let entry: LearningEntry
    let rendering: LearningRendering?
    let session: PracticeSessionState?

    @State private var currentStep: PracticeSessionStep = .prepare

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(titleKey: "practice.shadowing.title", subtitle: entry.title)
                if let session {
                    PracticeControlBar(
                        steps: session.steps,
                        currentStep: currentStep,
                        onSelectStep: { currentStep = $0 },
                        onNext: { currentStep = session.nextStep(after: currentStep) }
                    )
                    PracticeStepPanel(
                        step: currentStep,
                        targetText: session.targetText,
                        providerLabel: session.providerLabel
                    )
                } else {
                    CapabilityStatusRow(
                        localizedTitleKey: "practice.noContent.title",
                        localizedSummaryKey: "practice.noContent.summary",
                        status: .unavailable,
                        systemImage: "waveform",
                        action: nil
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle(localizedText("practice.title"))
        .langoPageBackground()
    }
}

private struct PracticeStepPanel: View {
    let step: PracticeSessionStep
    let targetText: String
    let providerLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                localizedText(labelTitleKey)
            } icon: {
                Image(systemName: labelIcon)
            }
            .font(.headline)
            Text(mainText)
                .font(.title3.weight(.semibold))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            Text(localizedString("practice.sourceBoundary", providerLabel))
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .langoPanel()
    }

    private var labelTitleKey: String {
        switch step {
        case .prepare:
            "practiceStep.prepareMaterial"
        case .shadow:
            "practiceStep.shadow"
        case .compare:
            "practiceStep.compare"
        case .completed:
            "practiceStep.completed"
        }
    }

    private var labelIcon: String {
        switch step {
        case .prepare:
            "text.magnifyingglass"
        case .shadow:
            "waveform"
        case .compare:
            "checklist"
        case .completed:
            "checkmark.circle"
        }
    }

    private var mainText: String {
        switch step {
        case .prepare:
            localizedString("practiceStep.prepare.body")
        case .shadow:
            targetText
        case .compare:
            localizedString("practiceStep.compare.body")
        case .completed:
            localizedString("practiceStep.completed.body")
        }
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
        localizedText("hero.subtitle.prefix")
            + Text(" \(languageSpace.targetLanguage) ")
            + localizedText("hero.subtitle.suffix")
    }
}

struct EntryCard: View {
    let entry: LearningEntry
    let targetLanguage: String
    let rendering: LearningRendering?
    let action: () -> Void

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
                        InlineStatusLabel(text: entry.practiceSummary, systemImage: "waveform")
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                }

                Text(entry.body)
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

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
