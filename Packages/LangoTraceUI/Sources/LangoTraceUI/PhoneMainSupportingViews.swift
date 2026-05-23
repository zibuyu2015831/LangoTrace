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
    var onGenerateLearningMaterial: (() -> Void)?
    var onCancelLearningMaterialGeneration: (() -> Void)?
    var onUpdateLearningText: ((String, String) -> Void)?
    var onAnalyzeCurrentLearningText: (() -> Void)?
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
                ReadOnlyEntryTextPanel(text: entry.body, emphasis: .secondary)
                if let rendering {
                    if let onUpdateLearningText, let onAnalyzeCurrentLearningText {
                        LearningMaterialEditorView(
                            rendering: rendering,
                            generationState: generationState,
                            targetLanguageName: languageSpace.targetLanguage,
                            onSave: { learningText in
                                onUpdateLearningText(rendering.id, learningText)
                            },
                            onReanalyze: onAnalyzeCurrentLearningText
                        )
                    } else {
                        ReadOnlyEntryTextPanel(text: rendering.targetText, emphasis: .primary)
                    }
                    SectionHeader(titleKey: "entryDetail.sentences.title")
                    ForEach(Array(rendering.sentences.enumerated()), id: \.element.id) { index, sentence in
                        SentencePairView(index: index + 1, sentence: sentence, onPractice: onPractice)
                    }
                } else if let onGenerateLearningMaterial {
                    TextPanel(
                        title: localizedString("entry.targetLanguage.title"),
                        text: localizedString("entry.rendering.pending")
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
                    TextPanel(
                        title: localizedString("entry.targetLanguage.title"),
                        text: localizedString("entry.rendering.pending")
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
}

private struct LearningMaterialEditorView: View {
    let rendering: LearningRendering
    let generationState: LearningMaterialGenerationState
    let targetLanguageName: String
    let onSave: (String) -> Void
    let onReanalyze: () -> Void

    @State private var draftText: String
    @State private var isEditorPresented = false

    init(
        rendering: LearningRendering,
        generationState: LearningMaterialGenerationState,
        targetLanguageName: String,
        onSave: @escaping (String) -> Void,
        onReanalyze: @escaping () -> Void
    ) {
        self.rendering = rendering
        self.generationState = generationState
        self.targetLanguageName = targetLanguageName
        self.onSave = onSave
        self.onReanalyze = onReanalyze
        _draftText = State(initialValue: rendering.targetText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                readOnlyLearningText
                    .padding(.trailing, textTrailingPadding)
                actionOverlay
            }
            if let statusMessage {
                Label {
                    localizedText(statusMessage.localizedKey)
                        .font(.footnote)
                        .foregroundStyle(statusMessage.color)
                } icon: {
                    Image(systemName: statusMessage.systemImage)
                        .foregroundStyle(statusMessage.color)
                }
                .accessibilityElement(children: .combine)
            }
            if generationState.analysisIsStale {
                localizedText("entry.rendering.learningText.stale")
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
        .langoPanel(padding: 14)
        .onChange(of: rendering.targetText) {
            draftText = rendering.targetText
        }
        .sheet(isPresented: $isEditorPresented) {
            LearningMaterialEditorSheet(
                draftText: $draftText,
                targetLanguageName: targetLanguageName,
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
            .presentationDetents([.large])
        }
    }

    private var actionOverlay: some View {
        HStack(spacing: 8) {
            if canReanalyze {
                Button {
                    onReanalyze()
                } label: {
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
            .accessibilityLabel(localizedText("entry.rendering.learningText.edit"))
        }
    }

    private var readOnlyLearningText: some View {
        Text(rendering.targetText)
            .font(.body)
            .lineSpacing(3)
            .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(localizedText("entry.rendering.learningText.accessibilityLabel"))
    }

    private var textTrailingPadding: CGFloat {
        canReanalyze ? 104 : 56
    }

    private var canSave: Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != rendering.targetText && !generationState.isRunning
    }

    private var canReanalyze: Bool {
        generationState.analysisIsStale && !generationState.isRunning
    }

    private var statusMessage: LearningMaterialEditorStatusMessage? {
        switch generationState {
        case .analyzing:
            LearningMaterialEditorStatusMessage(
                localizedKey: "entry.rendering.learningText.analyzing",
                systemImage: "sparkles",
                color: LangoTraceDesign.ColorToken.accent
            )
        case .failed:
            LearningMaterialEditorStatusMessage(
                localizedKey: "entry.rendering.learningText.analysisFailed",
                systemImage: "exclamationmark.triangle",
                color: LangoTraceDesign.ColorToken.stateError
            )
        default:
            nil
        }
    }
}

private struct LearningMaterialEditorStatusMessage {
    let localizedKey: String
    let systemImage: String
    let color: Color
}

private struct ReadOnlyEntryTextPanel: View {
    enum Emphasis {
        case primary
        case secondary
    }

    let text: String
    let emphasis: Emphasis

    var body: some View {
        Text(text)
            .font(emphasis == .primary ? .body.weight(.medium) : .body)
            .lineSpacing(4)
            .foregroundStyle(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .langoPanel()
    }

    private var textColor: Color {
        switch emphasis {
        case .primary:
            LangoTraceDesign.ColorToken.textPrimary
        case .secondary:
            LangoTraceDesign.ColorToken.textSecondary
        }
    }
}

private struct LearningMaterialEditorSheet: View {
    @Binding var draftText: String

    let targetLanguageName: String
    let canSave: Bool
    let isRunning: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $draftText)
                .font(.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .padding(20)
                .background(LangoTraceDesign.ColorToken.surfaceBase)
                .accessibilityLabel(localizedText("entry.rendering.learningText.accessibilityLabel"))
                .navigationTitle(sheetTitle)
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
    }

    private var sheetTitle: String {
        localizedString("entry.rendering.learningText.editTitle", targetLanguageName)
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
