import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Phone main chrome")
struct PhoneMainChromeTests {
    @Test("Home chrome keeps settings reachable and demo copy out of the main path")
    func homeChromeKeepsSettingsReachableAndDemoCopyOutOfMainPath() throws {
        let phoneSections = try String(contentsOf: sourceFileURL(named: "PhoneMainSections.swift"), encoding: .utf8)
        let contextToolbar = try String(
            contentsOf: sourceFileURL(named: "PhoneRootContextToolbar.swift"),
            encoding: .utf8
        )

        #expect(contextToolbar.contains("Button(action: onSettingsAction)"))
        #expect(contextToolbar.contains(#"accessibilityLabel(localizedText("tab.settings"))"#))
        #expect(contextToolbar.contains("Button(action: onLanguageSpaceAction)"))
        #expect(!phoneSections.contains("statusTextKey"))
        #expect(!phoneSections.contains("statusArgument"))

        for key in [
            "phone.entries.status",
            "phone.practice.status",
            "phone.memory.status",
            "phone.today.recent.subtitle",
        ] {
            #expect(!phoneSections.contains(key))
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
