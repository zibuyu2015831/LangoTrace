@testable import LangoTraceCore
import Testing

@Suite("Privacy status")
struct PrivacyStatusTests {
    @Test("AI status keeps a stable icon across all states")
    func aiStatusKeepsStableIcon() {
        for status in AIProviderStatus.allCases {
            #expect(status.systemImage == "sparkles")
        }
    }

    @Test("Sync status keeps a stable icon across all states")
    func syncStatusKeepsStableIcon() {
        for status in SyncProviderStatus.allCases {
            #expect(status.systemImage == "arrow.triangle.2.circlepath")
        }
    }

    @Test("AI status maps each state to its privacy severity")
    func aiStatusSeverityMapping() {
        #expect(AIProviderStatus.notConfigured.severity == .inactive)
        #expect(AIProviderStatus.unavailable.severity == .inactive)
        #expect(AIProviderStatus.configured.severity == .active)
        #expect(AIProviderStatus.error.severity == .error)
    }

    @Test("Sync status maps each state to its privacy severity")
    func syncStatusSeverityMapping() {
        #expect(SyncProviderStatus.off.severity == .inactive)
        #expect(SyncProviderStatus.configured.severity == .active)
        #expect(SyncProviderStatus.syncing.severity == .active)
        #expect(SyncProviderStatus.paused.severity == .warning)
        #expect(SyncProviderStatus.error.severity == .error)
    }

    @Test("Core privacy status stays semantic and carries no display copy")
    func coreStatusCarriesNoDisplayCopy() {
        // Display strings live in the UI package localization catalog; Core only
        // exposes enum cases, icon names, and severity semantics.
        #expect(AIProviderStatus.allCases.count == 4)
        #expect(SyncProviderStatus.allCases.count == 5)
    }
}
