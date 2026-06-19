import SwiftUI

private struct WelcomeTraceExample: Identifiable, Hashable {
    let id: String
    let sceneKey: String
    let levelKey: String
    let sourceNoteKey: String
    let rewrittenTextKey: String
    let audioCueKey: String
    let shadowingCueKey: String
}

private let welcomeTraceExamples = [
    WelcomeTraceExample(
        id: "cafe",
        sceneKey: "welcome.tracePreview.examples.cafe.scene",
        levelKey: "welcome.tracePreview.examples.cafe.level",
        sourceNoteKey: "welcome.tracePreview.examples.cafe.sourceNote",
        rewrittenTextKey: "welcome.tracePreview.examples.cafe.rewrittenText",
        audioCueKey: "welcome.tracePreview.examples.cafe.audioCue",
        shadowingCueKey: "welcome.tracePreview.examples.cafe.shadowingCue"
    ),
    WelcomeTraceExample(
        id: "commute",
        sceneKey: "welcome.tracePreview.examples.commute.scene",
        levelKey: "welcome.tracePreview.examples.commute.level",
        sourceNoteKey: "welcome.tracePreview.examples.commute.sourceNote",
        rewrittenTextKey: "welcome.tracePreview.examples.commute.rewrittenText",
        audioCueKey: "welcome.tracePreview.examples.commute.audioCue",
        shadowingCueKey: "welcome.tracePreview.examples.commute.shadowingCue"
    ),
    WelcomeTraceExample(
        id: "meeting",
        sceneKey: "welcome.tracePreview.examples.meeting.scene",
        levelKey: "welcome.tracePreview.examples.meeting.level",
        sourceNoteKey: "welcome.tracePreview.examples.meeting.sourceNote",
        rewrittenTextKey: "welcome.tracePreview.examples.meeting.rewrittenText",
        audioCueKey: "welcome.tracePreview.examples.meeting.audioCue",
        shadowingCueKey: "welcome.tracePreview.examples.meeting.shadowingCue"
    ),
]

struct WelcomeTracePreviewCarousel: View {
    let isExpanded: Bool
    let expandedCardHeight: CGFloat?

    @State private var selectedExampleID: String? = welcomeTraceExamples[0].id

    init(isExpanded: Bool, expandedCardHeight: CGFloat? = nil) {
        self.isExpanded = isExpanded
        self.expandedCardHeight = expandedCardHeight
    }

    var body: some View {
        VStack(spacing: isExpanded ? 10 : 8) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(welcomeTraceExamples) { example in
                        WelcomeTracePreviewCard(example: example, isExpanded: isExpanded)
                            .containerRelativeFrame(.horizontal)
                            .frame(height: cardHeight)
                            .id(example.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedExampleID)
            .frame(height: cardHeight)
            .accessibilityElement(children: .contain)
            .accessibilityValue(pageAccessibilityValue)

            WelcomeTracePageIndicator(
                examples: welcomeTraceExamples,
                selectedExampleID: $selectedExampleID
            )
        }
    }

    private var cardHeight: CGFloat {
        isExpanded ? expandedCardHeight ?? 388 : 246
    }

    private var pageAccessibilityValue: String {
        let currentIndex = welcomeTraceExamples.firstIndex { example in
            example.id == selectedExampleID
        } ?? 0
        return localizedString(
            "welcome.tracePreview.pageAccessibilityValue",
            currentIndex + 1,
            welcomeTraceExamples.count
        )
    }
}

private struct WelcomeTracePageIndicator: View {
    let examples: [WelcomeTraceExample]
    @Binding var selectedExampleID: String?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(examples.enumerated()), id: \.element.id) { _, example in
                Button {
                    selectedExampleID = example.id
                } label: {
                    Circle()
                        .fill(indicatorColor(for: example))
                        .frame(width: indicatorSize(for: example), height: indicatorSize(for: example))
                        // Keep the small dot visual while extending the hit area
                        // to the minimum touch target.
                        .frame(
                            width: LangoTraceDesign.Density.minimumTouchTarget,
                            height: LangoTraceDesign.Density.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText(example.sceneKey))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func indicatorColor(for example: WelcomeTraceExample) -> Color {
        example.id == selectedExampleID
            ? LangoTraceDesign.ColorToken.deepTeal
            : LangoTraceDesign.ColorToken.hairline
    }

    private func indicatorSize(for example: WelcomeTraceExample) -> CGFloat {
        example.id == selectedExampleID ? 7 : 6
    }
}

private struct WelcomeTracePreviewCard: View {
    let example: WelcomeTraceExample
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 20 : 14) {
            localizedText("welcome.tracePreview.title")
                .font((isExpanded ? Font.subheadline : Font.caption).weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                localizedText(example.sceneKey)
                    .font(isExpanded ? .title3.weight(.semibold) : .headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                localizedText(example.levelKey)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.teal)
            }

            if isExpanded {
                expandedLearningPreview
            } else {
                compactLearningPreview
            }
        }
        .langoPanel(padding: isExpanded ? 30 : 20)
        .accessibilityElement(children: .combine)
    }

    private var compactLearningPreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            localizedText(example.sourceNoteKey)
                .font(.subheadline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            localizedText(example.rewrittenTextKey)
                .font(.body.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            localizedText(example.shadowingCueKey)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
        }
    }

    private var expandedLearningPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreviewSection(titleKey: "welcome.tracePreview.sourceNoteTitle") {
                localizedText(example.sourceNoteKey)
            }
            PreviewSectionDivider()
            PreviewSection(titleKey: "welcome.tracePreview.rewrittenTextTitle") {
                localizedText(example.rewrittenTextKey)
            }
            PreviewSectionDivider()
            PreviewSection(titleKey: "welcome.tracePreview.audioCueTitle") {
                localizedText(example.audioCueKey)
            }
            PreviewSectionDivider()
            PreviewSection(titleKey: "welcome.tracePreview.shadowingCueTitle") {
                localizedText(example.shadowingCueKey)
            }
        }
    }
}

private struct PreviewSection<Content: View>: View {
    let titleKey: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            localizedText(titleKey)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            content
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PreviewSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(LangoTraceDesign.ColorToken.hairline.opacity(0.7))
            .frame(height: 1)
    }
}
