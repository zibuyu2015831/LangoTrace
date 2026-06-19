import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Language space content store binding")
struct LanguageSpaceContentStoreBindingTests {
    @Test("Root binds platform main view identity to the current language space")
    func rootBindsPlatformMainViewIdentityToCurrentLanguageSpace() throws {
        let source = try String(
            contentsOfFile: sourceFilePath("LangoTraceRootView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("PlatformMainView("))
        #expect(source.contains(".id(languageSpace.id)"))
    }
}

private func sourceFilePath(_ fileName: String) -> String {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources")
        .appendingPathComponent("LangoTraceUI")
        .appendingPathComponent(fileName)
        .path
}
