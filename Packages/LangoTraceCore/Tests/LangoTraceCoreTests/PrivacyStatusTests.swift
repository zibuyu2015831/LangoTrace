@testable import LangoTraceCore
import Testing

@Suite("Privacy status")
struct PrivacyStatusTests {
    @Test("AI status exposes stable icon, title, value, and explanation")
    func aiStatusExposesDisplayMetadata() {
        #expect(AIProviderStatus.notConfigured.systemImage == "sparkles")
        #expect(AIProviderStatus.notConfigured.title == "AI Provider")
        #expect(AIProviderStatus.notConfigured.value == "未配置")
        #expect(AIProviderStatus.notConfigured.summary.contains("当前不会发送"))
        #expect(AIProviderStatus.configured.value == "已配置")
        #expect(AIProviderStatus.configured.summary.contains("请求预览"))
    }

    @Test("Sync status exposes stable icon, title, value, and explanation")
    func syncStatusExposesDisplayMetadata() {
        #expect(SyncProviderStatus.off.systemImage == "arrow.triangle.2.circlepath")
        #expect(SyncProviderStatus.off.title == "同步")
        #expect(SyncProviderStatus.off.value == "未启用")
        #expect(SyncProviderStatus.off.summary.contains("数据仅保存在本机"))
        #expect(SyncProviderStatus.configured.value == "已配置")
        #expect(SyncProviderStatus.configured.summary.contains("配置范围"))
    }

    @Test("Configured and error states are distinguishable without changing primary icon semantics")
    func statusStateSemanticsAreStable() {
        #expect(AIProviderStatus.error.systemImage == AIProviderStatus.configured.systemImage)
        #expect(SyncProviderStatus.error.systemImage == SyncProviderStatus.configured.systemImage)
        #expect(AIProviderStatus.error.severity == .error)
        #expect(SyncProviderStatus.syncing.severity == .active)
        #expect(SyncProviderStatus.paused.severity == .warning)
    }
}
