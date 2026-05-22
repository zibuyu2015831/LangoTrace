import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Phone iOS convergence")
struct PhoneIOSConvergenceTests {
    @Test("iPhone memory page hides technical memory infrastructure")
    func iPhoneMemoryPageHidesTechnicalMemoryInfrastructure() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PhoneMainSections.swift"), encoding: .utf8)

        #expect(!source.contains("MemoryLayerSummaryView("))
        #expect(!source.contains("memory.vectorIndex.title"))
        #expect(!source.contains("memory.vectorIndex.body"))
    }

    @Test("iPhone record hero keeps photo writing and moves listening to practice")
    func iPhoneRecordHeroKeepsPhotoWritingAndMovesListeningToPractice() throws {
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let photoWritingPreview = try String(
            contentsOf: sourceFileURL(named: "PhonePhotoWritingPreviewView.swift"),
            encoding: .utf8
        )
        let practiceRows = try String(contentsOf: sourceFileURL(named: "PhonePracticeRows.swift"), encoding: .utf8)
        let sections = try String(contentsOf: sourceFileURL(named: "PhoneMainSections.swift"), encoding: .utf8)

        #expect(phoneMainView.contains("case .photoWritingPreview"))
        #expect(phoneMainView.contains("createMockPhotoWritingEntry()"))
        #expect(photoWritingPreview.contains("PhotoWritingPreviewView"))
        #expect(supportingViews.contains("photoWriting.startWithPhoto"))
        #expect(!supportingViews.contains(#"SecondaryActionChip(titleKey: "common.listen""#))
        #expect(practiceRows.contains("PracticeContinuePanel"))
        #expect(sections.contains("PracticeContinuePanel"))
    }

    @Test("iPhone default learning flow does not show persistent request previews")
    func iPhoneDefaultLearningFlowDoesNotShowPersistentRequestPreviews() throws {
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let header = try String(contentsOf: sourceFileURL(named: "EntryDetailHeader.swift"), encoding: .utf8)

        #expect(!supportingViews.contains("RequestPreviewCard(entry:"))
        #expect(!header.contains("entryDetail.header.boundary"))
        #expect(!supportingViews.contains("entryDetail.sentences.subtitle"))
        #expect(!supportingViews.contains("entryDetail.practiceEntry.subtitle"))
    }

    @Test("iPhone detail owns real generation entry while iPad and Mac stay unconnected")
    func iPhoneDetailOwnsRealGenerationEntry() throws {
        let phoneMainView = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)
        let supportingViews = try String(
            contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"),
            encoding: .utf8
        )
        let padSections = try String(contentsOf: sourceFileURL(named: "PadMainSections.swift"), encoding: .utf8)
        let macWorkspace = try String(contentsOf: sourceFileURL(named: "MacWorkspaceContentView.swift"), encoding: .utf8)

        #expect(phoneMainView.contains("onGenerateLearningMaterial"))
        #expect(phoneMainView.contains("contentStore.generateLearningMaterial"))
        #expect(supportingViews.contains("entry.rendering.generateLearningMaterial.title"))
        #expect(supportingViews.contains("entry.rendering.generateLearningMaterial.summary"))
        #expect(!padSections.contains("generateLearningMaterial"))
        #expect(!macWorkspace.contains("generateLearningMaterial"))
    }

    @Test("iPhone sentence listening uses local preview instead of development unavailable copy")
    func iPhoneSentenceListeningUsesLocalPreviewInsteadOfDevelopmentUnavailableCopy() throws {
        let components = try String(
            contentsOf: sourceFileURL(named: "LearningContentComponents.swift"),
            encoding: .utf8
        )
        let localizations = try String(
            contentsOf: sourceFileURL(named: "Resources/Localizable.xcstrings"),
            encoding: .utf8
        )

        #expect(components.contains("LocalListeningPreviewView"))
        #expect(!components.contains("UnavailableCapabilityView(content: ." + "listenOne)"))
        #expect(!components.contains("isListen" + "UnavailablePresented"))
        #expect(!localizations.contains("听力播放" + "规划中"))
        #expect(!localizations.contains("当前页面只展示" + "入口边界"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
