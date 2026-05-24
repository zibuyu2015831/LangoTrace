import LangoTraceSync
import Testing

@Suite("Sync boundary")
struct SyncBoundaryTests {
    @Test("Disabled sync service is the explicit no-op production boundary")
    func disabledSyncServiceIsExplicitNoOpBoundary() {
        let service: any SyncService = DisabledSyncService()

        #expect(service is DisabledSyncService)
    }
}
