@testable import LangoTrace
import XCTest

final class PracticeRecordingConfigurationTests: XCTestCase {
    func testInfoPlistsDeclareMicrophoneUsageDescription() throws {
        let root = try repositoryRoot()
        for relativePath in [
            "LangoTraceApp/Supporting/Info-iOS.plist",
            "LangoTraceApp/Supporting/Info-macOS.plist",
        ] {
            let url = root.appendingPathComponent(relativePath)
            let data = try Data(contentsOf: url)
            let plist = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            )
            let value = try XCTUnwrap(plist["NSMicrophoneUsageDescription"] as? String)
            XCTAssertTrue(value.contains("local"))
            XCTAssertTrue(value.contains("AI"))
        }
    }

    func testMacOSEntitlementsAllowAudioInput() throws {
        let root = try repositoryRoot()
        let entitlementsURL = root.appendingPathComponent("LangoTraceApp/Supporting/LangoTrace-macOS.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertEqual(plist["com.apple.security.device.audio-input"] as? Bool, true)

        let project = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        XCTAssertTrue(
            project.contains("CODE_SIGN_ENTITLEMENTS: LangoTraceApp/Supporting/LangoTrace-macOS.entitlements")
        )
    }

    func testMacOSEntitlementsAllowOutboundNetworkClient() throws {
        let root = try repositoryRoot()
        let entitlementsURL = root.appendingPathComponent("LangoTraceApp/Supporting/LangoTrace-macOS.entitlements")
        let data = try Data(contentsOf: entitlementsURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        // The sandboxed macOS app needs outbound network access for user-triggered
        // AI provider and TTS requests; without this key, signed builds block all requests.
        XCTAssertEqual(plist["com.apple.security.network.client"] as? Bool, true)
    }
}

private func repositoryRoot() throws -> URL {
    var url = URL(fileURLWithPath: #filePath)
    while url.pathComponents.count > 1 {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("project.yml").path) {
            return url
        }
        url.deleteLastPathComponent()
    }
    throw CocoaError(.fileNoSuchFile)
}
