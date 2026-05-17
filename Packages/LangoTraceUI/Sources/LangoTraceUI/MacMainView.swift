import LangoTraceCore
import SwiftUI

struct MacMainView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            main
            Divider()
            inspector
        }
        .frame(minWidth: 1120, minHeight: 720)
        .langoPageBackground()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(ProductIdentity.displayName)
                .font(.title2.weight(.semibold))
            LanguageSpaceBadge(languageSpace: languageSpace)
            SideItem(title: "今日", subtitle: "继续雨天咖啡馆", active: true)
            SideItem(title: "记录库", subtitle: "128 条生活片段", active: false)
            SideItem(title: "词句记忆", subtitle: "本地向量索引可重建", active: false)
            Spacer()
            Button {} label: {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 300, alignment: .topLeading)
    }

    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("语言资料库工作台")
                            .font(.largeTitle.weight(.semibold))
                        Text("Mac 端用于批量整理、搜索、导入导出和高级配置。当前为 Mock 骨架。")
                            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    }
                    Spacer()
                    Button {} label: {
                        Label("新建记录", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(alignment: .top, spacing: 14) {
                    TextPanel(title: "搜索与筛选", text: "搜索当前记录、词句、相似生活片段。后续接 SQLite FTS5 与本地向量索引。")
                    TextPanel(title: "批量导入", text: "拖入 Markdown、图片或音频，生成可学习的语言材料。")
                }

                TextPanel(
                    title: "当前记录",
                    text: """
                    雨天咖啡馆

                    I spent a long time at the cafe today. It kept drizzling outside, \
                    and I was in no hurry to go home.
                    """
                )
                AudioPanel()
            }
            .padding(26)
        }
        .frame(maxWidth: .infinity)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("INSPECTOR")
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            TextPanel(title: "请求预览", text: "即将发送：目标语言文本、用户选中的照片摘要、相似记忆 3 条。")
            TextPanel(title: "不会发送", text: "本地数据库、完整照片库、API Key、未选中的历史记录。")
            TextPanel(title: "快捷键", text: "Cmd+N 新建 · Cmd+K 命令面板 · Space 播放/暂停")
            Spacer()
        }
        .padding(24)
        .frame(width: 340, alignment: .topLeading)
    }
}
