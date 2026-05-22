import SwiftUI

extension WelcomeView {
    func compactContentWithBottomAction(size: CGSize) -> some View {
        ScrollView {
            compactMainContent(size: size)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            bottomActionArea(maxButtonWidth: 520)
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(LangoTraceDesign.ColorToken.paper)
        }
    }

    func usesWideLayout(in size: CGSize) -> Bool {
        horizontalSizeClass != .compact && size.width >= 760 && size.height >= 520
    }

    func iPadAllowsWideLayout(in size: CGSize) -> Bool {
        size.width > size.height
    }

    func usesPadPortraitLayout(in size: CGSize) -> Bool {
        horizontalSizeClass != .compact && size.width < size.height && size.width >= 760
    }

    func padPortraitContent(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            brandMark
            wideValueBlock
                .padding(.top, 28)
            statusStrip
                .padding(.top, 28)
            WelcomeTracePreviewCarousel(
                isExpanded: true,
                expandedCardHeight: iPadPortraitPreviewCardContentHeight(in: size)
            )
            .frame(width: iPadPortraitPreviewCardWidth(in: size))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 28)
            .langoSoftShadow()
            bottomActionArea(maxButtonWidth: iPadPortraitCTAMaxWidth(in: size))
                .padding(.top, 36)
        }
        .padding(.horizontal, 72)
        .padding(.top, iPadPortraitTopPadding(in: size))
        .padding(.bottom, 42)
        .frame(maxWidth: 760, minHeight: size.height, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func wideContent(size: CGSize) -> some View {
        HStack(alignment: .center, spacing: wideHorizontalSpacing(in: size)) {
            wideLeftColumn(size: size)
                .frame(width: leadingColumnWidth(in: size), alignment: .leading)

            WelcomeTracePreviewCarousel(
                isExpanded: true,
                expandedCardHeight: iPadPreviewCardContentHeight(in: size)
            )
            .frame(width: previewCardWidth(in: size))
            .frame(minHeight: previewCardMinHeight(in: size))
            .langoSoftShadow()
        }
        .padding(.horizontal, wideHorizontalPadding(in: size))
        .padding(.top, wideStageTopPadding(in: size))
        .padding(.bottom, wideStageBottomPadding(in: size))
        .frame(
            maxWidth: wideContentMaxWidth(in: size),
            minHeight: wideStageMinHeight(in: size),
            alignment: .center
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: size.height, alignment: .center)
    }

    private func compactMainContent(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            brandMark
            valueBlock
                .padding(.top, compactBrandTitleSpacing(in: size))
            statusStrip
                .padding(.top, compactBadgeTopSpacing(in: size))
            WelcomeTracePreviewCarousel(isExpanded: false)
                .frame(maxWidth: compactPreviewWidth(in: size))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, compactPreviewTopSpacing(in: size))
        }
        .padding(.horizontal, 28)
        .padding(.top, compactContentTopPadding(in: size))
        .padding(.bottom, 28)
        .frame(maxWidth: 520, minHeight: size.height, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func wideLeftColumn(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: wideLeftColumnSpacing(in: size)) {
            brandMark
            wideValueBlock
            statusStrip
            bottomActionArea(maxButtonWidth: ctaMaxWidth(in: size), centersInAvailableWidth: false)
                .padding(.top, wideCTATopPadding(in: size))
        }
    }

    private func iPadPortraitTopPadding(in size: CGSize) -> CGFloat {
        size.height >= 1180 ? 78 : 56
    }

    private func iPadPortraitPreviewCardWidth(in size: CGSize) -> CGFloat {
        min(size.width - 144, 640)
    }

    private func iPadPortraitPreviewCardContentHeight(in size: CGSize) -> CGFloat {
        size.height >= 1180 ? 430 : 400
    }

    private func iPadPortraitCTAMaxWidth(in size: CGSize) -> CGFloat {
        min(size.width - 144, 640)
    }

    private func compactBrandTitleSpacing(in size: CGSize) -> CGFloat {
        size.height < 760 ? 22 : 28
    }

    private func compactBadgeTopSpacing(in size: CGSize) -> CGFloat {
        size.height < 760 ? 26 : 32
    }

    private func compactPreviewTopSpacing(in size: CGSize) -> CGFloat {
        size.height < 760 ? 20 : 28
    }

    private func compactPreviewWidth(in size: CGSize) -> CGFloat {
        min(size.width - 72, 430)
    }

    private func compactContentTopPadding(in size: CGSize) -> CGFloat {
        size.height < 760 ? 24 : 34
    }

    private func wideContentTopPadding(in size: CGSize) -> CGFloat {
        wideStageTopPadding(in: size)
    }

    private func wideStageTopPadding(in _: CGSize) -> CGFloat {
        0
    }

    private func wideStageBottomPadding(in _: CGSize) -> CGFloat {
        0
    }

    private func wideStageMinHeight(in size: CGSize) -> CGFloat {
        min(max(size.height * 0.70, 600), 740)
    }

    private func wideHorizontalSpacing(in size: CGSize) -> CGFloat {
        size.width >= 1180 ? 56 : 44
    }

    private func wideHorizontalPadding(in size: CGSize) -> CGFloat {
        size.width >= 1180 ? 40 : 32
    }

    private func wideContentMaxWidth(in size: CGSize) -> CGFloat {
        size.width >= 1180 ? 1080 : 980
    }

    private func leadingColumnWidth(in size: CGSize) -> CGFloat {
        size.width >= 1180 ? 430 : 400
    }

    private func wideLeftColumnSpacing(in size: CGSize) -> CGFloat {
        size.width >= 1180 ? 34 : 28
    }

    private func previewCardWidth(in size: CGSize) -> CGFloat {
        min(max(size.width * 0.39, 500), 580)
    }

    private func previewCardMinHeight(in size: CGSize) -> CGFloat {
        size.width >= 1180 ? 500 : 450
    }

    private func iPadPreviewCardContentHeight(in size: CGSize) -> CGFloat {
        size.height >= 900 ? 452 : 420
    }

    private func ctaMaxWidth(in size: CGSize) -> CGFloat {
        size.width >= 1180 ? 380 : 340
    }

    private func wideCTATopPadding(in size: CGSize) -> CGFloat {
        size.height >= 900 ? 22 : 16
    }

    private var brandMark: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LangoTraceDesign.ColorToken.gold)
                .frame(width: 8, height: 8)
            Text("LangoTrace")
                .font(.caption.weight(.semibold))
                .tracking(0.2)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
        .accessibilityElement(children: .combine)
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            localizedText("welcome.valueTitle")
                .font(.system(.largeTitle, design: .default, weight: .medium))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            welcomeSubtitleText
                .font(.body)
        }
    }

    private var wideValueBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            localizedText("welcome.valueTitle")
                .font(.system(size: 46, weight: .medium, design: .default))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
            welcomeSubtitleText
                .font(.title3.weight(.medium))
        }
    }

    private var welcomeSubtitleText: some View {
        localizedText("welcome.valueSubtitle")
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
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

    private func bottomActionArea(maxButtonWidth: CGFloat, centersInAvailableWidth: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onFinished) {
                Label {
                    localizedText("welcome.cta.startSetup")
                } icon: {
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.primaryActionFill)
            .frame(maxWidth: maxButtonWidth)
        }
        .frame(maxWidth: maxButtonWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: centersInAvailableWidth ? .center : .leading)
    }
}

#if os(macOS)
    extension WelcomeView {
        func macWideContent(size: CGSize) -> some View {
            HStack(alignment: .center, spacing: macHorizontalSpacing(in: size)) {
                macLeftColumn(size: size)
                    .frame(width: macLeadingColumnWidth(in: size), alignment: .leading)

                WelcomeTracePreviewCarousel(
                    isExpanded: true,
                    expandedCardHeight: macPreviewCardContentHeight(in: size)
                )
                .frame(width: macPreviewCardWidth(in: size))
                .frame(minHeight: macPreviewCardMinHeight(in: size))
                .langoSoftShadow()
            }
            .padding(.horizontal, macHorizontalPadding(in: size))
            .padding(.top, macStageTopPadding(in: size))
            .padding(.bottom, macStageBottomPadding(in: size))
            .frame(
                maxWidth: macContentMaxWidth(in: size),
                minHeight: macStageMinHeight(in: size),
                alignment: .center
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(width: size.width, alignment: .center)
            .frame(minHeight: size.height, alignment: .center)
        }

        private func macLeftColumn(size: CGSize) -> some View {
            VStack(alignment: .leading, spacing: macLeftColumnSpacing(in: size)) {
                brandMark
                macValueBlock
                statusStrip
                bottomActionArea(maxButtonWidth: macCTAMaxWidth(in: size), centersInAvailableWidth: false)
                    .padding(.top, macCTATopPadding(in: size))
            }
        }

        private var macValueBlock: some View {
            VStack(alignment: .leading, spacing: 16) {
                localizedText("welcome.valueTitle")
                    .font(.system(size: 64, weight: .medium, design: .default))
                    .lineSpacing(11)
                    .fixedSize(horizontal: false, vertical: true)
                welcomeSubtitleText
                    .font(.title2.weight(.medium))
            }
        }

        private func macStageTopPadding(in size: CGSize) -> CGFloat {
            size.height >= 780 ? 54 : 42
        }

        private func macStageBottomPadding(in size: CGSize) -> CGFloat {
            size.height >= 780 ? 54 : 40
        }

        private func macStageMinHeight(in size: CGSize) -> CGFloat {
            min(max(size.height * 0.72, 620), 760)
        }

        private func macHorizontalSpacing(in size: CGSize) -> CGFloat {
            size.width >= 1180 ? 20 : 18
        }

        private func macHorizontalPadding(in size: CGSize) -> CGFloat {
            size.width >= 1180 ? 28 : 24
        }

        private func macContentMaxWidth(in size: CGSize) -> CGFloat {
            size.width >= 1600 ? 1460 : size.width >= 1360 ? 1280 : min(size.width - 72, 1120)
        }

        private func macLeadingColumnWidth(in size: CGSize) -> CGFloat {
            size.width >= 1600 ? 660 : size.width >= 1360 ? 600 : 470
        }

        private func macPreviewCardWidth(in size: CGSize) -> CGFloat {
            size.width >= 1600 ? 720 : size.width >= 1360 ? 600 : 540
        }

        private func macPreviewCardMinHeight(in size: CGSize) -> CGFloat {
            size.height >= 780 ? 600 : 520
        }

        private func macPreviewCardContentHeight(in size: CGSize) -> CGFloat {
            size.height >= 780 ? 500 : 450
        }

        private func macLeftColumnSpacing(in size: CGSize) -> CGFloat {
            size.height >= 780 ? 30 : 24
        }

        private func macCTATopPadding(in size: CGSize) -> CGFloat {
            size.height >= 780 ? 22 : 16
        }

        private func macCTAMaxWidth(in size: CGSize) -> CGFloat {
            size.width >= 1180 ? 470 : 400
        }
    }
#endif
