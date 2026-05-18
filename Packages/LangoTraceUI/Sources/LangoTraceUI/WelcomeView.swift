import SwiftUI

struct WelcomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            LangoTraceDesign.ColorToken.paper.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    if usesWideLayout(in: proxy.size) {
                        wideContent(size: proxy.size)
                    } else {
                        compactContent(size: proxy.size)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func usesWideLayout(in size: CGSize) -> Bool {
        horizontalSizeClass != .compact && size.width >= 760 && size.height >= 520
    }

    private func compactContent(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: compactVerticalSpacing(in: size)) {
            brandMark
            valueBlock
            statusStrip
            WelcomeTracePreviewCard(isExpanded: false)
            ctaBlock
        }
        .padding(.horizontal, 28)
        .padding(.top, compactContentTopPadding(in: size))
        .padding(.bottom, 34)
        .frame(maxWidth: 520, minHeight: size.height, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func wideContent(size: CGSize) -> some View {
        HStack(alignment: .center, spacing: 64) {
            VStack(alignment: .leading, spacing: 28) {
                brandMark
                valueBlock
                statusStrip
                ctaBlock
            }
            .frame(maxWidth: 440, alignment: .leading)

            WelcomeTracePreviewCard(isExpanded: true)
                .frame(maxWidth: 470)
                .langoSoftShadow()
        }
        .padding(.horizontal, 64)
        .padding(.top, wideContentTopPadding(in: size))
        .padding(.bottom, 56)
        .frame(maxWidth: 1120, minHeight: size.height, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func compactVerticalSpacing(in size: CGSize) -> CGFloat {
        size.height < 760 ? 16 : 20
    }

    private func compactContentTopPadding(in size: CGSize) -> CGFloat {
        size.height < 760 ? 24 : 34
    }

    private func wideContentTopPadding(in size: CGSize) -> CGFloat {
        size.height > 1100 ? 180 : 96
    }

    private var brandMark: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LangoTraceDesign.ColorToken.gold)
                .frame(width: 8, height: 8)
            Text("LANGOTRACE")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            localizedText("welcome.valueTitle")
                .font(.system(.largeTitle, design: .default, weight: .semibold))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            localizedText("welcome.valueSubtitle")
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                trustBadges
            }
            VStack(alignment: .leading, spacing: 10) {
                trustBadges
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedText("welcome.accessibility.badges"))
    }

    @ViewBuilder private var trustBadges: some View {
        CapsuleLabel(systemImage: "lock.shield") {
            localizedText("app.badge.localFirst")
        }
        CapsuleLabel(systemImage: "sparkles") {
            localizedText("app.badge.aiOptional")
        }
    }

    private var ctaBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onFinished) {
                Label {
                    localizedText("welcome.cta.startSetup")
                } icon: {
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.deepTeal)

            localizedText("welcome.setupTimeLocalNote")
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WelcomeTracePreviewCard: View {
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 18 : 14) {
            localizedText("welcome.tracePreview.title")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                localizedText("welcome.tracePreview.scene")
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)

                if isExpanded {
                    localizedText("welcome.tracePreview.body")
                        .font(.subheadline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isExpanded {
                expandedLearningPreview
            } else {
                compactLearningPreview
            }
        }
        .langoPanel(padding: isExpanded ? 26 : 20)
        .accessibilityElement(children: .combine)
    }

    private var compactLearningPreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            localizedText("welcome.tracePreview.vocabulary")
                .font(.subheadline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            localizedText("welcome.tracePreview.expression")
                .font(.body.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            localizedText("welcome.tracePreview.compactPractice")
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
        }
    }

    private var expandedLearningPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            PreviewSection(titleKey: "welcome.tracePreview.vocabularyTitle") {
                localizedText("welcome.tracePreview.vocabulary")
            }
            PreviewSection(titleKey: "welcome.tracePreview.expressionTitle") {
                localizedText("welcome.tracePreview.expression")
            }
            PreviewSection(titleKey: "welcome.tracePreview.practiceTitle") {
                localizedText("welcome.tracePreview.practice")
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

private struct CapsuleLabel<Title: View>: View {
    let systemImage: String
    @ViewBuilder let title: Title

    var body: some View {
        Label {
            title
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        .background(LangoTraceDesign.ColorToken.paleTeal)
        .clipShape(Capsule())
    }
}
