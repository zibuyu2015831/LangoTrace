import Foundation
import Testing

@Suite("Welcome home layout")
struct WelcomeHomeLayoutTests {
    @Test("Next welcome optimization keeps iPad wide and Mac CTA restrained")
    func nextWelcomeOptimizationKeepsIPadWideAndMacCTARestrained() throws {
        let source = try layoutSourceText()

        #expect(source.contains("private func previewCardWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("min(max(size.width * 0.39, 500), 580)"))
        #expect(source.contains("private func ctaMaxWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("size.width >= 1180 ? 380 : 340"))
        #expect(source.contains("private func wideLeftColumn(size: CGSize) -> some View"))
        #expect(source.contains("""
        bottomActionArea(maxButtonWidth: ctaMaxWidth(in: size), centersInAvailableWidth: false)
        """))
        #expect(source.contains(".frame(width: previewCardWidth(in: size))"))
        #expect(source.contains(".frame(minHeight: previewCardMinHeight(in: size))"))
    }

    @Test("Mac welcome wide layout binds the CTA to the left narrative column")
    func macWelcomeWideLayoutBindsCTAtoLeftNarrativeColumn() throws {
        let source = try welcomeSourceText()

        #expect(source.contains("#if os(macOS)"))
        #expect(source.contains("macWideContent(size: proxy.size)"))
        #expect(source.contains("extension WelcomeView"))
        #expect(source.contains("func macWideContent(size: CGSize) -> some View"))
        #expect(source.contains("private func macLeftColumn(size: CGSize) -> some View"))
        #expect(source.contains("""
        bottomActionArea(maxButtonWidth: macCTAMaxWidth(in: size), centersInAvailableWidth: false)
        """))
        #expect(source.contains("expandedCardHeight: macPreviewCardContentHeight(in: size)"))
        #expect(source.contains("private func macPreviewCardWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("private func macContentMaxWidth(in size: CGSize) -> CGFloat"))
    }

    @Test("Mac welcome preview is larger without changing the iPad card range")
    func macWelcomePreviewIsLargerWithoutChangingIPadCardRange() throws {
        let source = try layoutSourceText()

        #expect(source.contains("min(max(size.width * 0.39, 500), 580)"))
        #expect(source.contains("size.width >= 1600 ? 1460 : size.width >= 1360 ? 1280 : min(size.width - 72, 1120)"))
        #expect(source.contains("size.width >= 1600 ? 720 : size.width >= 1360 ? 600 : 540"))
        #expect(source.contains("size.height >= 780 ? 600 : 520"))
        #expect(source.contains("size.width >= 1180 ? 20 : 18"))
        #expect(source.contains("size.width >= 1180 ? 28 : 24"))
        #expect(source.contains("macValueBlock"))
    }

    @Test("iPad welcome wide layout follows the reference stage proportions")
    func iPadWelcomeWideLayoutFollowsReferenceStageProportions() throws {
        let source = try welcomeSourceText()

        #expect(source.contains("iPadAllowsWideLayout(in: proxy.size)"))
        #expect(source.contains("""
        expandedCardHeight: iPadPreviewCardContentHeight(in: size)
        """))
        #expect(source.contains("func iPadAllowsWideLayout(in size: CGSize) -> Bool"))
        #expect(source.contains("size.width > size.height"))
        #expect(source.contains("private func iPadPreviewCardContentHeight(in size: CGSize) -> CGFloat"))
        #expect(source.contains("size.height >= 900 ? 452 : 420"))
        #expect(source.contains("private func wideStageTopPadding(in _: CGSize) -> CGFloat"))
        #expect(source.contains("private func wideStageBottomPadding(in _: CGSize) -> CGFloat"))
        #expect(source.contains("wideStageTopPadding(in: size)"))
        #expect(source.contains("wideStageBottomPadding(in: size)"))
        #expect(source.contains("size.width >= 1180 ? 56 : 44"))
        #expect(source.contains("size.width >= 1180 ? 40 : 32"))
        #expect(source.contains("size.width >= 1180 ? 1080 : 980"))
        #expect(source.contains("size.width >= 1180 ? 430 : 400"))
        #expect(!source.contains("size.height >= 900 ? 148 : 86"))
        #expect(source.contains(".frame(minHeight: size.height, alignment: .center)"))
    }

    @Test("Mac welcome wide layout uses a tighter larger desktop stage")
    func macWelcomeWideLayoutUsesTighterLargerDesktopStage() throws {
        let source = try layoutSourceText()

        #expect(source.contains("size.width >= 1600 ? 1460 : size.width >= 1360 ? 1280 : min(size.width - 72, 1120)"))
        #expect(source.contains("size.width >= 1180 ? 20 : 18"))
        #expect(source.contains("size.width >= 1180 ? 28 : 24"))
        #expect(source.contains("size.width >= 1600 ? 660 : size.width >= 1360 ? 600 : 470"))
        #expect(source.contains("size.width >= 1600 ? 720 : size.width >= 1360 ? 600 : 540"))
        #expect(source.contains("size.height >= 780 ? 600 : 520"))
        #expect(source.contains("size.height >= 780 ? 500 : 450"))
        #expect(source.contains("size.width >= 1180 ? 470 : 400"))
        #expect(source.contains(".font(.system(size: 64, weight: .medium, design: .default))"))
    }

    @Test("Mac welcome wide layout keeps the title and card inside the visible window")
    func macWelcomeWideLayoutKeepsTitleAndCardInsideVisibleWindow() throws {
        let source = try layoutSourceText()

        #expect(source.contains("func macWideContent(size: CGSize) -> some View"))
        #expect(source.contains(".frame(width: size.width, alignment: .center)"))
        #expect(source.contains(".frame(minHeight: size.height, alignment: .center)"))
        #expect(source.contains("private func macLeadingColumnWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("size.width >= 1600 ? 660 : size.width >= 1360 ? 600 : 470"))
        #expect(source.contains("private func macPreviewCardWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("size.width >= 1600 ? 720 : size.width >= 1360 ? 600 : 540"))
        #expect(!source.contains("min(max(size.width * 0.48, 760), 900)"))
    }

    @Test("iPad portrait welcome uses an expanded single-column stage")
    func iPadPortraitWelcomeUsesExpandedSingleColumnStage() throws {
        let source = try welcomeSourceText()

        #expect(source.contains("usesPadPortraitLayout(in: proxy.size)"))
        #expect(source.contains("padPortraitContent(size: proxy.size)"))
        #expect(source.contains("func usesPadPortraitLayout(in size: CGSize) -> Bool"))
        #expect(source.contains("horizontalSizeClass != .compact && size.width < size.height"))
        #expect(source.contains("func padPortraitContent(size: CGSize) -> some View"))
        #expect(source.contains("expandedCardHeight: iPadPortraitPreviewCardContentHeight(in: size)"))
        #expect(source.contains("private func iPadPortraitPreviewCardWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("min(size.width - 144, 640)"))
        #expect(source.contains("private func iPadPortraitPreviewCardContentHeight(in size: CGSize) -> CGFloat"))
        #expect(source.contains("size.height >= 1180 ? 430 : 400"))
        #expect(source.contains("bottomActionArea(maxButtonWidth: iPadPortraitCTAMaxWidth(in: size))"))
    }

    @Test("Expanded welcome cards use section dividers like the iPad reference")
    func expandedWelcomeCardsUseSectionDividersLikeTheIPadReference() throws {
        let source = try sourceText(named: "WelcomeTracePreviewCarousel.swift")

        #expect(source.contains("private struct PreviewSectionDivider: View"))
        #expect(source.contains("PreviewSectionDivider()"))
        #expect(source.contains("LangoTraceDesign.ColorToken.hairline"))
    }

    @Test("iPad welcome layout uses a centered stage instead of a compressed top-left block")
    func iPadWelcomeLayoutUsesCenteredStageInsteadOfCompressedTopLeftBlock() throws {
        let source = try layoutSourceText()

        #expect(source.contains("private func wideStageMinHeight(in size: CGSize) -> CGFloat"))
        #expect(source.contains("HStack(alignment: .center, spacing: wideHorizontalSpacing(in: size))"))
        #expect(source.contains("wideLeftColumn(size: size)"))
        #expect(source.contains(".frame(width: leadingColumnWidth(in: size), alignment: .leading)"))
        #expect(source.contains("maxWidth: wideContentMaxWidth(in: size),"))
        #expect(source.contains("minHeight: wideStageMinHeight(in: size),"))
        #expect(source.contains("private func wideStageTopPadding(in _: CGSize) -> CGFloat"))
        #expect(source.contains(".frame(minHeight: size.height, alignment: .center)"))
    }

    private func layoutSourceText() throws -> String {
        try sourceText(named: "WelcomeView+Layout.swift")
    }

    private func welcomeSourceText() throws -> String {
        try [
            sourceText(named: "WelcomeView.swift"),
            layoutSourceText(),
            sourceText(named: "WelcomeTracePreviewCarousel.swift"),
        ].joined(separator: "\n")
    }

    private func sourceText(named relativePath: String) throws -> String {
        try String(contentsOf: sourceFileURL(named: relativePath), encoding: .utf8)
    }

    private func sourceFileURL(named relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(relativePath)
    }
}
