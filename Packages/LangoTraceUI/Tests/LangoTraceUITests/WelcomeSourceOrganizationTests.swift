import Foundation
import Testing

@Suite("Welcome source organization")
struct WelcomeSourceOrganizationTests {
    @Test("Welcome implementation is split before lint length limits")
    func welcomeImplementationIsSplitBeforeLintLengthLimits() throws {
        let sourceRootURL = try packageSourceRootURL()
        let welcomeViewSource = try String(
            contentsOf: sourceRootURL.appendingPathComponent("WelcomeView.swift"),
            encoding: .utf8
        )
        let layoutSourceURL = sourceRootURL.appendingPathComponent("WelcomeView+Layout.swift")

        #expect(FileManager.default.fileExists(atPath: layoutSourceURL.path()))
        #expect(!welcomeViewSource.contains("func compactContentWithBottomAction(size: CGSize) -> some View"))
        #expect(!welcomeViewSource.contains("func macWideContent(size: CGSize) -> some View"))
    }

    @Test("Welcome layout tests are split out of the content optimization suite")
    func welcomeLayoutTestsAreSplitOutOfTheContentOptimizationSuite() throws {
        let testRootURL = try packageTestRootURL()
        let optimizationSource = try String(
            contentsOf: testRootURL.appendingPathComponent("WelcomeHomeOptimizationTests.swift"),
            encoding: .utf8
        )
        let layoutTestsURL = testRootURL.appendingPathComponent("WelcomeHomeLayoutTests.swift")

        #expect(FileManager.default.fileExists(atPath: layoutTestsURL.path()))
        #expect(!optimizationSource.contains("Mac welcome wide layout uses a tighter larger desktop stage"))
        #expect(!optimizationSource.contains("iPad welcome wide layout follows the reference stage proportions"))
    }

    private func packageSourceRootURL() throws -> URL {
        try packageRootURL()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
    }

    private func packageTestRootURL() throws -> URL {
        try packageRootURL()
            .appendingPathComponent("Tests")
            .appendingPathComponent("LangoTraceUITests")
    }

    private func packageRootURL() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
