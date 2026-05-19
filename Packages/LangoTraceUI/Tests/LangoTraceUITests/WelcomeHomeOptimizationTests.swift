import Foundation
import Testing

@Suite("Welcome home optimization")
struct WelcomeHomeOptimizationTests {
    @Test("Welcome view uses value-first copy, optional AI, setup CTA, and preview card")
    func welcomeViewUsesOptimizedHomeCopyKeys() throws {
        let source = try welcomeSourceText()

        for expectedSnippet in [
            #"localizedText("welcome.valueTitle")"#,
            #"localizedText("welcome.valueSubtitle")"#,
            #"localizedText("app.badge.aiOptional")"#,
            #"localizedText("welcome.tracePreview.title")"#,
            "example.rewrittenTextKey",
            #"localizedText("welcome.cta.startSetup")"#,
        ] {
            #expect(source.contains(expectedSnippet), "WelcomeView is missing \(expectedSnippet)")
        }

        for retiredSnippet in [
            "ProductIdentity.displayName",
            "ProductIdentity.chineseSlogan",
            "ProductIdentity.englishSlogan",
            #"localizedText("app.badge.aiNotConfigured")"#,
            #"localizedText("common.continue")"#,
            #"localizedText("welcome.setupTimeLocalNote")"#,
            "vocabularyKey",
            "expressionKey",
            "practiceKey",
        ] {
            #expect(!source.contains(retiredSnippet), "WelcomeView still uses retired snippet \(retiredSnippet)")
        }
    }

    @Test("Welcome subtitle stays shared across compact iPad and Mac layouts")
    func welcomeSubtitleStaysSharedAcrossCompactIPadAndMacLayouts() throws {
        let source = try sourceText(named: "WelcomeView.swift")

        #expect(source.contains("private var welcomeSubtitleText: some View"))
        #expect(source.contains(#"localizedText("welcome.valueSubtitle")"#))
        #expect(source.contains("welcomeSubtitleText"))

        let subtitleKeyReferenceCount = source
            .components(separatedBy: #"localizedText("welcome.valueSubtitle")"#)
            .count - 1
        #expect(
            subtitleKeyReferenceCount == 1,
            "Welcome subtitle must have one localization key reference shared by compact, iPad, and Mac layouts."
        )
    }

    @Test("Welcome trace card model uses the life-to-shadowing learning loop")
    func welcomeTraceCardModelUsesLifeToShadowingLearningLoop() throws {
        let source = try welcomeSourceText()

        for expectedSnippet in [
            "let levelKey: String",
            "let sourceNoteKey: String",
            "let rewrittenTextKey: String",
            "let audioCueKey: String",
            "let shadowingCueKey: String",
            #"id: "meeting""#,
            #"id: "cafe""#,
            #"id: "commute""#,
            #"levelKey: "welcome.tracePreview.examples.meeting.level""#,
            #"sourceNoteKey: "welcome.tracePreview.examples.meeting.sourceNote""#,
            #"rewrittenTextKey: "welcome.tracePreview.examples.meeting.rewrittenText""#,
            #"audioCueKey: "welcome.tracePreview.examples.meeting.audioCue""#,
            #"shadowingCueKey: "welcome.tracePreview.examples.meeting.shadowingCue""#,
        ] {
            #expect(source.contains(expectedSnippet), "Welcome trace card is missing \(expectedSnippet)")
        }

        let cafeIndex = source.range(of: #"id: "cafe""#)?.lowerBound ?? source.endIndex
        let commuteIndex = source.range(of: #"id: "commute""#)?.lowerBound ?? source.endIndex
        let meetingIndex = source.range(of: #"id: "meeting""#)?.lowerBound ?? source.startIndex
        #expect(
            cafeIndex < commuteIndex && commuteIndex < meetingIndex,
            "Welcome trace examples must be sorted from beginner to advanced for every platform."
        )

        for retiredSnippet in [
            "let vocabularyKey: String",
            "let expressionKey: String",
            "let practiceKey: String",
            "example.vocabularyKey",
            "example.expressionKey",
            "example.practiceKey",
        ] {
            #expect(!source.contains(retiredSnippet), "Welcome trace card still uses retired field \(retiredSnippet)")
        }
    }

    @Test("Mobile and iPad welcome layouts keep optimized content in the first viewport")
    func welcomeLayoutsKeepOptimizedContentInFirstViewport() throws {
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

        #expect(!source.contains("Spacer(minLength:"))
        #expect(source.contains("private func compactPreviewTopSpacing(in size: CGSize) -> CGFloat"))
        #expect(source.contains("private func compactContentTopPadding(in size: CGSize) -> CGFloat"))
        #expect(source.contains("private func wideContentTopPadding(in size: CGSize) -> CGFloat"))
        #expect(source.contains(
            "minHeight: wideStageMinHeight(in: size),"
        ))
        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .center)"))
        #expect(source.contains(".frame(minHeight: size.height, alignment: .center)"))
    }

    @Test("Next welcome optimization separates mobile action area and centers preview")
    func nextWelcomeOptimizationSeparatesMobileActionAreaAndCentersPreview() throws {
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

        #expect(source.contains("safeAreaInset(edge: .bottom)"))
        #expect(source.contains("compactMainContent(size: size)"))
        #expect(source.contains("bottomActionArea(maxButtonWidth: 520)"))
        #expect(source.contains(".frame(maxWidth: compactPreviewWidth(in: size))"))
        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .center)"))
    }

    @Test("Next welcome optimization keeps iPad wide and Mac CTA restrained")
    func nextWelcomeOptimizationKeepsIPadWideAndMacCTARestrained() throws {
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

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
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

        #expect(source.contains("#if os(macOS)"))
        #expect(source.contains("macWideContent(size: proxy.size)"))
        #expect(source.contains("private extension WelcomeView"))
        #expect(source.contains("func macWideContent(size: CGSize) -> some View"))
        #expect(source.contains("func macLeftColumn(size: CGSize) -> some View"))
        #expect(source.contains("""
        bottomActionArea(maxButtonWidth: macCTAMaxWidth(in: size), centersInAvailableWidth: false)
        """))
        #expect(source.contains("expandedCardHeight: macPreviewCardContentHeight(in: size)"))
        #expect(source.contains("func macPreviewCardWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("func macContentMaxWidth(in size: CGSize) -> CGFloat"))
    }

    @Test("Mac welcome preview is larger without changing the iPad card range")
    func macWelcomePreviewIsLargerWithoutChangingIPadCardRange() throws {
        let source = try sourceText(named: "WelcomeView.swift")

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
        let source = try sourceText(named: "WelcomeView.swift")

        #expect(source.contains("iPadAllowsWideLayout(in: proxy.size)"))
        #expect(source.contains("""
        expandedCardHeight: iPadPreviewCardContentHeight(in: size)
        """))
        #expect(source.contains("private func iPadAllowsWideLayout(in size: CGSize) -> Bool"))
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
        let source = try sourceText(named: "WelcomeView.swift")

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
        let source = try sourceText(named: "WelcomeView.swift")

        #expect(source.contains("func macWideContent(size: CGSize) -> some View"))
        #expect(source.contains(".frame(width: size.width, alignment: .center)"))
        #expect(source.contains(".frame(minHeight: size.height, alignment: .center)"))
        #expect(source.contains("func macLeadingColumnWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("size.width >= 1600 ? 660 : size.width >= 1360 ? 600 : 470"))
        #expect(source.contains("func macPreviewCardWidth(in size: CGSize) -> CGFloat"))
        #expect(source.contains("size.width >= 1600 ? 720 : size.width >= 1360 ? 600 : 540"))
        #expect(!source.contains("min(max(size.width * 0.48, 760), 900)"))
    }

    @Test("iPad portrait welcome uses an expanded single-column stage")
    func iPadPortraitWelcomeUsesExpandedSingleColumnStage() throws {
        let source = try sourceText(named: "WelcomeView.swift")

        #expect(source.contains("usesPadPortraitLayout(in: proxy.size)"))
        #expect(source.contains("padPortraitContent(size: proxy.size)"))
        #expect(source.contains("private func usesPadPortraitLayout(in size: CGSize) -> Bool"))
        #expect(source.contains("horizontalSizeClass != .compact && size.width < size.height"))
        #expect(source.contains("private func padPortraitContent(size: CGSize) -> some View"))
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
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

        #expect(source.contains("private func wideStageMinHeight(in size: CGSize) -> CGFloat"))
        #expect(source.contains("HStack(alignment: .center, spacing: wideHorizontalSpacing(in: size))"))
        #expect(source.contains("wideLeftColumn(size: size)"))
        #expect(source.contains(".frame(width: leadingColumnWidth(in: size), alignment: .leading)"))
        #expect(source.contains("maxWidth: wideContentMaxWidth(in: size),"))
        #expect(source.contains("minHeight: wideStageMinHeight(in: size),"))
        #expect(source.contains("private func wideStageTopPadding(in _: CGSize) -> CGFloat"))
        #expect(source.contains(".frame(minHeight: size.height, alignment: .center)"))
    }

    @Test("Welcome brand mark uses product case instead of all caps")
    func welcomeBrandMarkUsesProductCaseInsteadOfAllCaps() throws {
        let source = try String(contentsOf: sourceFileURL(named: "WelcomeView.swift"), encoding: .utf8)

        #expect(source.contains(#"Text("LangoTrace")"#))
        #expect(!source.contains("LANGOTRACE"))
    }

    @Test("Welcome examples use three static trace cards in a swipeable carousel")
    func welcomeExamplesUseThreeStaticTraceCardsInSwipeableCarousel() throws {
        let source = try welcomeSourceText()

        #expect(source.contains("private struct WelcomeTraceExample: Identifiable"))
        #expect(source.contains("private let welcomeTraceExamples"))
        #expect(source.contains(#"id: "cafe""#))
        #expect(source.contains(#"id: "commute""#))
        #expect(source.contains(#"id: "meeting""#))
        #expect(source.contains("struct WelcomeTracePreviewCarousel: View"))
        #expect(source.contains("@State private var selectedExampleID"))
        #expect(source.contains("ScrollView(.horizontal)"))
        #expect(source.contains(".scrollTargetBehavior(.paging)"))
        #expect(source.contains(".scrollPosition(id: $selectedExampleID)"))
        #expect(source.contains(".frame(height: cardHeight)"))
        #expect(source.contains("WelcomeTracePageIndicator"))
        #expect(!source.contains("Timer.publish"))
    }

    @Test("Welcome carousel keeps platform layout boundaries")
    func welcomeCarouselKeepsPlatformLayoutBoundaries() throws {
        let source = try welcomeSourceText()

        #expect(source.contains("WelcomeTracePreviewCarousel(isExpanded: false)"))
        #expect(source.contains("expandedCardHeight: iPadPreviewCardContentHeight(in: size)"))
        #expect(source.contains("expandedCardHeight: macPreviewCardContentHeight(in: size)"))
        #expect(!source.contains("PhoneWelcomeTracePreviewCarousel"))
        #expect(!source.contains("PadWelcomeTracePreviewCarousel"))
        #expect(source.contains(".frame(maxWidth: compactPreviewWidth(in: size))"))
        #expect(source.contains(".frame(width: previewCardWidth(in: size))"))
        #expect(source.contains(".frame(minHeight: previewCardMinHeight(in: size))"))
        #expect(source.contains("accessibilityValue(pageAccessibilityValue)"))
        #expect(source.contains(#""welcome.tracePreview.pageAccessibilityValue""#))
    }

    @Test("Welcome carousel keeps page indicators close and compact cards visible")
    func welcomeCarouselKeepsPageIndicatorsCloseAndCompactCardsVisible() throws {
        let welcomeSource = try sourceText(named: "WelcomeView.swift")
        let carouselSource = try sourceText(named: "WelcomeTracePreviewCarousel.swift")

        #expect(welcomeSource.contains("size.height < 760 ? 20 : 28"))
        #expect(carouselSource.contains("VStack(spacing: isExpanded ? 10 : 8)"))
        #expect(carouselSource.contains("private var cardHeight: CGFloat"))
        #expect(carouselSource.contains("isExpanded ? expandedCardHeight ?? 388 : 246"))
        #expect(welcomeSource.contains("expandedCardHeight: macPreviewCardContentHeight(in: size)"))
        #expect(carouselSource.contains(".frame(height: cardHeight)"))
        #expect(!carouselSource.contains(".frame(minHeight: isExpanded ? 420 : 270)"))
    }

    @Test("Welcome optimization copy exists for every interface language")
    func welcomeOptimizationCopyExistsForEveryInterfaceLanguage() throws {
        let catalog = try WelcomeStringCatalog.load(from: sourceFileURL(named: "Resources/Localizable.xcstrings"))
        let requiredKeys = [
            "app.badge.aiOptional",
            "welcome.valueTitle",
            "welcome.valueSubtitle",
            "welcome.cta.startSetup",
            "welcome.tracePreview.title",
            "welcome.tracePreview.scene",
            "welcome.tracePreview.body",
            "welcome.tracePreview.sourceNoteTitle",
            "welcome.tracePreview.rewrittenTextTitle",
            "welcome.tracePreview.audioCueTitle",
            "welcome.tracePreview.shadowingCueTitle",
            "welcome.tracePreview.pageAccessibilityValue",
            "welcome.tracePreview.examples.cafe.scene",
            "welcome.tracePreview.examples.cafe.level",
            "welcome.tracePreview.examples.cafe.sourceNote",
            "welcome.tracePreview.examples.cafe.rewrittenText",
            "welcome.tracePreview.examples.cafe.audioCue",
            "welcome.tracePreview.examples.cafe.shadowingCue",
            "welcome.tracePreview.examples.commute.scene",
            "welcome.tracePreview.examples.commute.level",
            "welcome.tracePreview.examples.commute.sourceNote",
            "welcome.tracePreview.examples.commute.rewrittenText",
            "welcome.tracePreview.examples.commute.audioCue",
            "welcome.tracePreview.examples.commute.shadowingCue",
            "welcome.tracePreview.examples.meeting.scene",
            "welcome.tracePreview.examples.meeting.level",
            "welcome.tracePreview.examples.meeting.sourceNote",
            "welcome.tracePreview.examples.meeting.rewrittenText",
            "welcome.tracePreview.examples.meeting.audioCue",
            "welcome.tracePreview.examples.meeting.shadowingCue",
        ]
        let requiredLocales = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]

        for key in requiredKeys {
            let entry = try #require(catalog.strings[key], "Missing catalog key \(key)")
            for locale in requiredLocales {
                let value = entry.localizedValues[locale]
                #expect(value?.isEmpty == false, "Missing \(locale) localization for \(key)")
            }
        }
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

    private func sourceText(named relativePath: String) throws -> String {
        try String(contentsOf: sourceFileURL(named: relativePath), encoding: .utf8)
    }

    private func welcomeSourceText() throws -> String {
        try [
            sourceText(named: "WelcomeView.swift"),
            sourceText(named: "WelcomeTracePreviewCarousel.swift"),
        ].joined(separator: "\n")
    }
}

private struct WelcomeStringCatalog: Decodable {
    let strings: [String: WelcomeStringCatalogEntry]

    static func load(from url: URL) throws -> WelcomeStringCatalog {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WelcomeStringCatalog.self, from: data)
    }
}

private struct WelcomeStringCatalogEntry: Decodable {
    let localizations: [String: WelcomeStringCatalogLocalization]?

    var localizedValues: [String: String] {
        (localizations ?? [:]).reduce(into: [String: String]()) { result, element in
            result[element.key] = element.value.stringUnit?.value
        }
    }
}

private struct WelcomeStringCatalogLocalization: Decodable {
    let stringUnit: WelcomeStringCatalogStringUnit?
}

private struct WelcomeStringCatalogStringUnit: Decodable {
    let value: String
}
