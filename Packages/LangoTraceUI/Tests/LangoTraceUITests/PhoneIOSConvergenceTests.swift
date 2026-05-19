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
