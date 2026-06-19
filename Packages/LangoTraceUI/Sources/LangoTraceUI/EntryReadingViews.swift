import LangoTraceCore
import LangoTraceData
import SwiftUI

/// Store-connected wrapper for the bilingual reading page. It reads the LIVE rendering from
/// the content store (not a route snapshot) so edits / regeneration in the detail page are
/// reflected when returning here, and TTS targets the current text.
struct EntryReadingStoreView: View {
    let languageSpace: LanguageSpacePreview
    let entryID: String
    @ObservedObject var contentStore: LearningContentStore

    var body: some View {
        if let entry = contentStore.entry(id: entryID) {
            EntryReadingView(
                presentation: EntryReadingPresentation.make(from: contentStore.rendering(for: entry)),
                sentenceAudioPlaybackStates: contentStore.sentenceAudioPlaybackStates,
                activeSequenceSentenceID: contentStore.activeSequenceSentenceID,
                isSequenceActive: contentStore.isSentenceSequenceActive,
                onListenSentence: { index in
                    guard let rendering = contentStore.rendering(for: entry),
                          rendering.sentences.indices.contains(index)
                    else { return }
                    Task {
                        await contentStore.handleSentenceAudioTap(
                            rendering: rendering,
                            sentence: rendering.sentences[index],
                            sentenceIndex: index,
                            languageSpace: languageSpace
                        )
                    }
                },
                onToggleSequence: {
                    Task {
                        if contentStore.isSentenceSequenceActive {
                            await contentStore.stopSentenceSequence()
                            return
                        }
                        guard let rendering = contentStore.rendering(for: entry),
                              !rendering.sentences.isEmpty
                        else { return }
                        await contentStore.playSentenceSequence(
                            rendering: rendering,
                            languageSpace: languageSpace,
                            startingAt: 0
                        )
                    }
                }
            )
            .task(id: entry.id) {
                // Reset any sentence playback / sequence inherited from the detail page so the
                // two surfaces (which share the store's playback state) do not cross-talk.
                await contentStore.stopSentenceSequence()
            }
        }
    }
}

/// Bilingual immersive reading surface for a learning entry's rendering: the full target
/// text laid out sentence-by-sentence, tapping a sentence reveals its native translation
/// and note, with a reading font-size control. Continuous playback is layered on in a
/// later phase; for now each sentence has its own listen control.
struct EntryReadingView: View {
    let presentation: EntryReadingPresentation
    let sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState]
    let activeSequenceSentenceID: String?
    let isSequenceActive: Bool
    let onListenSentence: (Int) -> Void
    let onToggleSequence: () -> Void

    @AppStorage(EntryReadingPreferenceKey.fontScale) private var fontScaleRaw = EntryReadingFontScale.default.rawValue
    @State private var revealState = EntryReadingRevealState()

    private enum ReadingMetrics {
        static let targetBaseSize: CGFloat = 19
        static let translationBaseSize: CGFloat = 16
        static let noteBaseSize: CGFloat = 14
    }

    private var fontScale: EntryReadingFontScale {
        EntryReadingFontScale(rawValue: fontScaleRaw) ?? .default
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                fontControlRow
                if presentation.hasSentences {
                    ForEach(Array(presentation.sentences.enumerated()), id: \.element.id) { index, sentence in
                        sentenceCard(sentence, index: index)
                    }
                } else if presentation.showsFullTextFallback {
                    fullTextCard
                } else {
                    emptyCard
                }
            }
            .padding(20)
        }
        .navigationTitle(localizedString("entry.reading.title"))
        .langoPageBackground()
    }

    private var fontControlRow: some View {
        HStack(spacing: 8) {
            Button {
                fontScaleRaw = fontScale.decreased().rawValue
            } label: {
                Image(systemName: "textformat.size.smaller")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .disabled(!fontScale.canDecrease)
            .accessibilityLabel(localizedText("entry.reading.fontSize.decrease"))
            Button {
                fontScaleRaw = fontScale.increased().rawValue
            } label: {
                Image(systemName: "textformat.size.larger")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .disabled(!fontScale.canIncrease)
            .accessibilityLabel(localizedText("entry.reading.fontSize.increase"))
            Spacer(minLength: 0)
            if presentation.hasSentences {
                Button(action: onToggleSequence) {
                    Image(systemName: isSequenceActive ? "stop.fill" : "play.fill")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .accessibilityLabel(localizedText(
                    isSequenceActive ? "entry.reading.playAll.stop" : "entry.reading.playAll"
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sentenceCard(_ sentence: EntryReadingPresentation.Sentence, index: Int) -> some View {
        let revealed = revealState.isRevealed(sentence.id)
        let isActiveInSequence = activeSequenceSentenceID == sentence.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sentence.target)
                        .font(.system(size: ReadingMetrics.targetBaseSize * fontScale.multiplier, weight: .medium))
                        .lineSpacing(5)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if revealed {
                        revealedContent(sentence)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        revealState.toggle(sentence.id)
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(localizedText("entry.reading.reveal.hint"))
                listenButton(sentenceID: sentence.id, index: index)
            }
        }
        .langoPanel(padding: 16)
        .overlay {
            if isActiveInSequence {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.panel, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.accent, lineWidth: 2)
            }
        }
    }

    @ViewBuilder
    private func revealedContent(_ sentence: EntryReadingPresentation.Sentence) -> some View {
        if !sentence.translation.isEmpty {
            Text(sentence.translation)
                .font(.system(size: ReadingMetrics.translationBaseSize * fontScale.multiplier))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if !sentence.note.isEmpty {
            Text(sentence.note)
                .font(.system(size: ReadingMetrics.noteBaseSize * fontScale.multiplier))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func listenButton(sentenceID: String, index: Int) -> some View {
        let state = sentenceAudioPlaybackStates[sentenceID] ?? .idle
        return Button {
            onListenSentence(index)
        } label: {
            Image(systemName: state.listenButtonSystemImage)
                .font(.headline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(LangoTraceDesign.ColorToken.borderSubtle, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedText(state.listenButtonTitleKey))
    }

    private var fullTextCard: some View {
        Text(presentation.fullTargetText)
            .font(.system(size: ReadingMetrics.targetBaseSize * fontScale.multiplier, weight: .medium))
            .lineSpacing(5)
            .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .langoPanel(padding: 16)
    }

    private var emptyCard: some View {
        LocalizedText("entry.reading.empty")
            .font(.callout)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .langoPanel(padding: 16)
    }
}
