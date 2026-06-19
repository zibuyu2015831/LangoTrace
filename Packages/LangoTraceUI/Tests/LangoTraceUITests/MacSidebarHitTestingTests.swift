import Foundation
import Testing

@Suite("Mac sidebar hit testing")
struct MacSidebarHitTestingTests {
    @Test("Sidebar items keep full row hit testing and desktop affordances")
    func sidebarItemsKeepFullRowHitTestingAndDesktopAffordances() throws {
        let macMainView = try String(contentsOf: sourceFileURL(named: "MacMainView.swift"), encoding: .utf8)

        for expected in [
            "MacSidebarItem(",
            "selectSection(section)",
            ".contentShape(Rectangle())",
            ".focusable()",
            ".focusEffectDisabled()",
            ".onHover",
            ".contextMenu",
            ".accessibilityAddTraits(active ? .isSelected : [])",
        ] {
            #expect(macMainView.contains(expected))
        }
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
