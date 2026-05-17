import LangoTraceData
import SwiftUI

struct MacInspectorContent: View {
    let route: MacWorkspaceRoute
    let selectedSection: MacWorkspaceSection
    let entries: [LearningEntry]
    let settingsCapabilities: [SettingsCapability]
    let contentRepository: InMemoryLearningContentRepository

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case let .entryDetail(entryID):
            if let entry = entries.first(where: { $0.id == entryID }) {
                RequestPreviewCard(entry: entry, rendering: contentRepository.rendering(for: entry.id))
                TextPanel(title: "隐私边界", text: "当前详情只读取内存 mock 内容，不访问网络、Keychain 或真实数据库。")
            } else {
                TextPanel(title: "没有记录", text: "请选择记录库中的记录。")
            }
        case .practice:
            TextPanel(title: "练习状态", text: "当前只切换本地 mock 练习步骤，不播放音频、不录音、不保存结果。")
            TextPanel(title: "后续能力", text: "语音播放、录音、评分和听写结果需要 Speech / TTS 模块接入。")
        case let .settings(kind):
            if let capability = settingsCapabilities.first(where: { $0.kind == kind }) {
                TextPanel(title: capability.kind.title, text: capability.detail)
                TextPanel(title: "后续接入条件", text: capability.nextRequirement)
            }
        case .unavailable:
            TextPanel(title: "不可用能力", text: "当前入口只展示页面闭环，不会触发导入、导出、同步或外部请求。")
        case .overview:
            overviewInspector
        }
    }

    @ViewBuilder
    private var overviewInspector: some View {
        switch selectedSection {
        case .today:
            TextPanel(title: "本地优先", text: "今日工作台使用内存 mock 内容，用于验证 Mac 页面闭环。")
        case .entries:
            TextPanel(title: "记录库", text: "选择一条记录后，Inspector 会显示请求预览和隐私边界。")
        case .practice:
            TextPanel(title: "练习", text: "练习会话为 Local Mock，不接入真实音频和录音。")
        case .memory:
            TextPanel(title: "记忆", text: "向量索引是本地可重建派生数据，当前未接入。")
        case .importExport:
            TextPanel(title: "导入导出", text: "导入导出需要真实数据库、附件目录和文件安全边界后再实现。")
        case .settings:
            TextPanel(title: "设置", text: "设置页展示能力边界，不保存 API Key、同步配置或导出文件。")
        }
    }
}
