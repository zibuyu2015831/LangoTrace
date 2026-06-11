import Foundation
import Testing

@Suite("Platform view hardening")
struct PlatformViewHardeningTests {
    @Test("Pad sidebar scrolls timeline content lazily while the footer stays pinned")
    func padSidebarScrollsTimelineContentLazilyWhileFooterStaysPinned() throws {
        let source = try self.source("PadMainSections.swift")
        let scrollIndex = try #require(source.range(of: "ScrollView {")?.lowerBound)
        let footerIndex = try #require(source.range(of: "LanguageSpaceFooter(")?.lowerBound)

        #expect(source.contains("LazyVStack(spacing: 10)"))
        // The footer is rendered after (outside) the scroll region.
        #expect(scrollIndex < footerIndex)
    }

    @Test("Entry list sections render lazily on phone and mac")
    func entryListSectionsRenderLazilyOnPhoneAndMac() throws {
        let phoneSections = try source("PhoneMainSections.swift")
        let macWorkspace = try source("MacWorkspaceContentView.swift")

        #expect(phoneSections.contains("LazyVStack(alignment: .leading, spacing: 20)"))
        #expect(macWorkspace.contains("LazyVStack(alignment: .leading, spacing: 12)"))
    }

    @Test("Reading phone home keeps a single large title from the navigation bar")
    func readingPhoneHomeKeepsSingleLargeTitle() throws {
        let source = try self.source("ReadingViews.swift")

        #expect(source.contains(".navigationTitle(localizedString(\"tab.reading\"))"))
        #expect(!source.contains(".font(.largeTitle.weight(.semibold))"))
        #expect(source.contains("reading.library.subtitle"))
    }

    @Test("Reading document detail honors Reduce Motion for panel animations")
    func readingDocumentDetailHonorsReduceMotion() throws {
        let source = try self.source("ReadingViews.swift")

        #expect(source.contains("@Environment(\\.accessibilityReduceMotion) private var reduceMotion"))
        #expect(source.contains("reduceMotion ? nil : .easeInOut(duration: 0.22)"))
        #expect(source.contains("reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity)"))
        #expect(!source.contains(".animation(.easeInOut(duration: 0.22)"))
    }

    @Test("Reading document editor uses its own title and localized source format")
    func readingDocumentEditorUsesOwnTitleAndLocalizedSourceFormat() throws {
        let source = try self.source("ReadingViews.swift")

        #expect(source.contains(".navigationTitle(localizedString(\"reading.document.editTitle\"))"))
        #expect(!source.contains("settings.languageSpace.management.editTitle"))
        #expect(source.contains("Text(sourceFormat.displayName)"))
        #expect(!source.contains("Text(sourceFormat.rawValue)"))
    }

    @Test("Compact learning panel close and copy controls meet the minimum touch target")
    func compactLearningPanelCloseAndCopyControlsMeetMinimumTouchTarget() throws {
        let source = try self.source("ReadingViewComponents.swift")

        #expect(source.contains(".accessibilityLabel(localizedString(\"common.close\"))"))
        #expect(source.contains("width: LangoTraceDesign.Density.minimumTouchTarget"))
    }

    @Test("Provider text fields expose their visual title to assistive tech")
    func providerTextFieldsExposeVisualTitleToAssistiveTech() throws {
        let source = try self.source("AIProviderSettingsComponents.swift")
        let fieldIndex = try #require(source.range(of: "TextField(\"\", text: $text)")?.lowerBound)
        let labelRange = try #require(
            source.range(of: ".accessibilityLabel(localizedText(titleKey))", range: fieldIndex ..< source.endIndex)
        )

        #expect(!labelRange.isEmpty)
    }

    @Test("Small onboarding and sidebar controls extend hit areas to the minimum touch target")
    func smallControlsExtendHitAreasToMinimumTouchTarget() throws {
        for file in ["OnboardingFormControls.swift", "PadSidebarControls.swift", "WelcomeTracePreviewCarousel.swift"] {
            let source = try self.source(file)
            #expect(source.contains("LangoTraceDesign.Density.minimumTouchTarget"), "\(file) lacks touch target fix")
        }
    }

    @Test("Settings scene no-space boundary uses its own localization key")
    func settingsSceneNoSpaceBoundaryUsesOwnLocalizationKey() throws {
        let source = try self.source("LangoTraceSettingsSceneView.swift")

        #expect(source.contains("settings.noLanguageSpace.boundary"))
        #expect(!source.contains("settings.sync.detail"))
    }

    @Test("Settings capability detail never crashes on a missing language space")
    func settingsCapabilityDetailNeverCrashesOnMissingLanguageSpace() throws {
        let source = try self.source("SettingsCapabilityDetailView.swift")

        #expect(!source.contains("preconditionFailure"))
        #expect(source.contains("noLanguageSpaceBoundaryContent("))
    }

    private func source(_ name: String) throws -> String {
        try String(contentsOf: langoTraceUISourceFileURL(named: name), encoding: .utf8)
    }
}
