import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PracticeSentenceListView: View {
    let entry: LearningEntry
    let rendering: LearningRendering?
    let languageSpace: LanguageSpacePreview
    let sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState]
    let onListenSentence: (LearningRendering, RenderingSentence, Int) -> Void
    let onPracticeSentence: (PracticeSessionRouteSeed) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(titleKey: "practice.shadowing.title", subtitle: entry.title)
                if let rendering {
                    ForEach(Array(rendering.sentences.enumerated()), id: \.element.id) { index, sentence in
                        SentencePairView(
                            index: index + 1,
                            sentence: sentence,
                            playbackState: sentenceAudioPlaybackStates[sentence.id] ?? .idle,
                            onListen: {
                                onListenSentence(rendering, sentence, index)
                            },
                            onPractice: {
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
                            }
                        )
                    }
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

struct PracticeSessionView: View {
    let languageSpaceID: String
    let routeSeed: PracticeSessionRouteSeed
    let actions: PracticeActions

    @StateObject private var viewModel: PracticeSessionViewModel

    init(
        languageSpaceID: String,
        routeSeed: PracticeSessionRouteSeed,
        actions: PracticeActions
    ) {
        self.languageSpaceID = languageSpaceID
        self.routeSeed = routeSeed
        self.actions = actions
        _viewModel = StateObject(
            wrappedValue: PracticeSessionViewModel(
                languageSpaceID: languageSpaceID,
                snapshot: routeSeed.snapshot,
                actions: actions
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    titleKey: "practice.shadowing.title",
                    subtitle: routeSeed.snapshot.targetTextSnapshot
                )
                PracticeSnapshotPanel(snapshot: routeSeed.snapshot)
                if let session = viewModel.session {
                    PracticeControlBar(
                        session: session,
                        isRecording: viewModel.isRecording,
                        onStartRecording: {
                            Task { await viewModel.startRecording() }
                        },
                        onStopRecording: {
                            Task { await viewModel.stopRecording() }
                        },
                        onComplete: {
                            Task { await viewModel.completeLatestRecording() }
                        }
                    )
                    PracticeStepPanel(session: session)
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
        .task {
            await viewModel.load()
        }
    }
}

private struct PracticeSnapshotPanel: View {
    let snapshot: PracticeSentenceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let translation = snapshot.translationSnapshot {
                Text(translation)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            Text(snapshot.targetTextSnapshot)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let note = snapshot.noteSnapshot {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
        .langoPanel()
    }
}

private struct PracticeStepPanel: View {
    let session: PracticeSession

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
            Text(detailText)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .langoPanel()
    }

    private var labelTitleKey: String {
        switch session.currentStep {
        case .shadowing:
            "practiceStep.shadow"
        case .recording:
            "practiceStep.compare"
        case .completion:
            "practiceStep.completed"
        }
    }

    private var labelIcon: String {
        switch session.currentStep {
        case .shadowing:
            "waveform"
        case .recording:
            "record.circle"
        case .completion:
            "checkmark.circle"
        }
    }

    private var mainText: String {
        switch session.currentStep {
        case .shadowing:
            localizedString("practiceStep.shadow.body")
        case .recording:
            localizedString("practice.recording.inProgress")
        case .completion:
            if session.completedRecordingID == nil {
                localizedString("practiceStep.compare.body")
            } else {
                localizedString("practiceStep.completed.body")
            }
        }
    }

    private var detailText: String {
        session.status == .completed
            ? localizedString("practice.recording.completedLocal")
            : localizedString("practice.recording.guidance")
    }
}
