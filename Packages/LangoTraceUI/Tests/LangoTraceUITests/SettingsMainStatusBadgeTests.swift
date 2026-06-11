import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Settings main status badges")
struct SettingsMainStatusBadgeTests {
    @Test("settings index rows hide development status badges")
    func settingsIndexRowsHideDevelopmentStatusBadges() throws {
        let phoneSections = try source(named: "PhoneMainSections.swift")
        let padSections = try source(named: "PadMainSections.swift")
        let macWorkspace = try source(named: "MacWorkspaceContentView.swift")
        let macSettingsScene = try source(named: "LangoTraceSettingsSceneView.swift")

        for source in [phoneSections, padSections, macWorkspace, macSettingsScene] {
            #expect(source.contains("showsStatusBadge: false"))
        }
    }

    @Test("capability status row keeps badge visible unless caller opts out")
    func capabilityStatusRowKeepsBadgeVisibleUnlessCallerOptsOut() throws {
        let components = try source(named: "LearningContentComponents.swift")

        #expect(components.contains("let showsStatusBadge: Bool"))
        #expect(components.contains("showsStatusBadge: Bool = true"))
        #expect(components.contains("if showsStatusBadge {"))
        #expect(components.contains("CapabilityStatusBadge(status: status)"))
        #expect(components.contains("guard showsStatusBadge else {"))
        #expect(components.contains(
            "titleText + localizedText(\"accessibility.listSeparator\") + localizedText(status.localizedTitleKey)"
        ))
    }

    private func source(named fileName: String) throws -> String {
        try String(contentsOf: sourceFileURL(named: fileName), encoding: .utf8)
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
