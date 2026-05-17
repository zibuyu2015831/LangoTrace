import LangoTraceCore
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        TabView {
            TodayView(languageSpace: languageSpace)
                .tabItem { Label("今日", systemImage: "sun.max") }
            EntriesView(languageSpace: languageSpace)
                .tabItem { Label("记录", systemImage: "square.and.pencil") }
            PracticeView(languageSpace: languageSpace)
                .tabItem { Label("练习", systemImage: "waveform") }
            MemoryView(languageSpace: languageSpace)
                .tabItem { Label("记忆", systemImage: "archivebox") }
            SettingsView(languageSpace: languageSpace)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

private struct PhonePage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    content
                }
                .padding(20)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("语言空间与筛选")
                }
            }
            .langoPageBackground()
        }
    }
}

struct TodayView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(
            title: "今日",
            subtitle: "\(languageSpace.displayContext) · 本地优先 · 未配置 AI"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("今天记录一点生活")
                    .font(.title2.weight(.semibold))
                Text("写一句、拍一张照片，或把今天想说的话留给之后的英语练习。")
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                HStack {
                    ActionChip(title: "写一句", systemImage: "pencil")
                    ActionChip(title: "拍照", systemImage: "camera")
                }
            }
            .langoPanel()

            SampleEntryCard()
        }
    }
}

struct EntriesView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(title: "记录", subtitle: languageSpace.displayContext) {
            SampleEntryCard()
            CompactPanel(title: "写给朋友的感谢", text: "正式表达 · 英语 · 昨天")
            CompactPanel(title: "会议复盘", text: "职场表达 · 英语 · 本周")
        }
    }
}

struct PracticeView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(title: "练习", subtitle: "\(languageSpace.targetLanguage) 听说读写") {
            CompactPanel(title: "跟读", text: "2 句待练 · 0.85x")
            CompactPanel(title: "听写", text: "雨天咖啡馆 · 3 分钟")
            CompactPanel(title: "回译", text: "把目标语言译回母语，巩固表达")
        }
    }
}

struct MemoryView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(title: "记忆", subtitle: "词句、相似片段和长期轨迹") {
            CompactPanel(title: "收藏词句", text: "drizzling · in no hurry · watched people passing by")
            CompactPanel(title: "相似生活片段", text: "去年写过“在车站等雨停”，可复用 listening to the rain。")
            CompactPanel(title: "向量索引", text: "本地可重建 · 默认不同步")
        }
    }
}

struct SettingsView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(title: "设置", subtitle: "隐私、同步和 AI 请求由用户掌控") {
            CompactPanel(title: "语言空间", text: languageSpace.displayContext)
            CompactPanel(title: "AI Provider", text: "未配置 · OpenAI-compatible")
            CompactPanel(title: "对象存储", text: "未配置 · S3 / R2 / WebDAV")
            CompactPanel(title: "本地优先", text: "照片、记录和 API Key 默认不发送")
        }
    }
}

private struct ActionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(LangoTraceDesign.ColorToken.paleTeal)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CompactPanel: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
    }
}

private struct SampleEntryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("雨天咖啡馆")
                .font(.headline)
            Text("今天在咖啡馆坐了很久。外面一直下小雨，我没有急着回家。")
                .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            Divider()
            Text("I spent a long time at the cafe today. It kept drizzling outside, and I was in no hurry to go home.")
                .font(.callout.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
        }
        .langoPanel()
    }
}
