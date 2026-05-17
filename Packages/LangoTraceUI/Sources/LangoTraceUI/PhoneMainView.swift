import LangoTraceCore
import SwiftUI

struct PhoneMainView: View {
    let languageSpace: LanguageSpacePreview

    @State private var selectedTab: PhoneRootTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(languageSpace: languageSpace)
                .tabItem { Label(PhoneRootTab.today.title, systemImage: "sun.max") }
                .tag(PhoneRootTab.today)
            EntriesView(languageSpace: languageSpace)
                .tabItem { Label(PhoneRootTab.entries.title, systemImage: "square.and.pencil") }
                .tag(PhoneRootTab.entries)
            PracticeView(languageSpace: languageSpace)
                .tabItem { Label(PhoneRootTab.practice.title, systemImage: "waveform") }
                .tag(PhoneRootTab.practice)
            MemoryView(languageSpace: languageSpace)
                .tabItem { Label(PhoneRootTab.memory.title, systemImage: "archivebox") }
                .tag(PhoneRootTab.memory)
            SettingsView(languageSpace: languageSpace)
                .tabItem { Label(PhoneRootTab.settings.title, systemImage: "gearshape") }
                .tag(PhoneRootTab.settings)
        }
        .simultaneousGesture(tabSwipeGesture)
        .phoneTabBarBackground()
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                selectedTab = selectedTab.tab(
                    horizontalTranslation: Double(value.translation.width),
                    verticalTranslation: Double(value.translation.height)
                )
            }
    }
}

private extension View {
    @ViewBuilder
    func phoneTabBarBackground() -> some View {
        #if os(iOS)
            toolbarBackground(LangoTraceDesign.ColorToken.paper, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        #else
            self
        #endif
    }
}

private struct PhonePage<Content: View>: View {
    let title: String
    let languageSpace: LanguageSpacePreview
    let statusText: String
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PhoneContextHeader(languageSpace: languageSpace, statusText: statusText)
                    content
                }
                .padding(20)
                .padding(.bottom, 92)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Image(systemName: "chevron.down.circle")
                    }
                    .accessibilityLabel("切换语言空间")
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
            languageSpace: languageSpace,
            statusText: "本地优先 · 未配置 AI"
        ) {
            HeroActionCard(languageSpace: languageSpace)

            SectionHeader(title: "最近记录", subtitle: "生活内容会成为之后的听读和跟读材料")
            SampleEntryCard(languageSpace: languageSpace)
        }
    }
}

struct EntriesView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(
            title: "记录",
            languageSpace: languageSpace,
            statusText: "日记 · 照片 · 目标语言写作"
        ) {
            SectionHeader(title: "继续记录", subtitle: "每条记录都归入当前语言空间")
            SampleEntryCard(languageSpace: languageSpace)
            CompactPanel(
                title: "写给朋友的感谢",
                text: "正式表达 · \(languageSpace.targetLanguage) · 昨天",
                systemImage: "envelope"
            )
            CompactPanel(
                title: "会议复盘",
                text: "职场表达 · \(languageSpace.targetLanguage) · 本周",
                systemImage: "briefcase"
            )
            CompactPanel(
                title: "手写文章录入",
                text: "后续支持拍照识别、校对和 AI 修改。",
                systemImage: "camera.viewfinder"
            )
        }
    }
}

struct PracticeView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(
            title: "练习",
            languageSpace: languageSpace,
            statusText: "\(languageSpace.targetLanguage) 听说读写"
        ) {
            SectionHeader(title: "从生活记录练起", subtitle: "练习入口与原始记录保持关联")
            CompactPanel(title: "跟读", text: "2 句待练 · 0.85x", systemImage: "waveform")
            CompactPanel(title: "听写", text: "雨天咖啡馆 · 3 分钟", systemImage: "ear")
            CompactPanel(title: "回译", text: "把目标语言译回母语，巩固表达。", systemImage: "arrow.left.arrow.right")
            CompactPanel(title: "自主写作检查", text: "后续支持直接用目标语言写作并由 AI 修改。", systemImage: "checkmark.seal")
        }
    }
}

struct MemoryView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(
            title: "记忆",
            languageSpace: languageSpace,
            statusText: "词句、相似片段和长期轨迹"
        ) {
            SectionHeader(title: "个人语言记忆", subtitle: "不是孤立单词，而是来自生活上下文的表达")
            CompactPanel(
                title: "收藏词句",
                text: "drizzling · in no hurry · watched people passing by",
                systemImage: "bookmark"
            )
            CompactPanel(
                title: "整句表达",
                text: "I was in no hurry to go home.",
                systemImage: "quote.bubble"
            )
            CompactPanel(
                title: "相似生活片段",
                text: "去年写过“在车站等雨停”，可复用 listening to the rain。",
                systemImage: "point.3.connected.trianglepath.dotted"
            )
            CompactPanel(
                title: "错误模式",
                text: "后续从目标语言写作和回译结果中提取。",
                systemImage: "exclamationmark.magnifyingglass"
            )
            CompactPanel(title: "向量索引", text: "本地可重建 · 默认不同步", systemImage: "square.stack.3d.up")
        }
    }
}

struct SettingsView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        PhonePage(
            title: "设置",
            languageSpace: languageSpace,
            statusText: "隐私、同步和 AI 请求由用户掌控"
        ) {
            SectionHeader(title: "当前空间", subtitle: "配置不抢占记录和学习主流程")
            CompactPanel(title: "语言空间", text: languageSpace.displayContext, systemImage: "text.badge.star")
            CompactPanel(title: "AI Provider", text: "未配置 · OpenAI-compatible", systemImage: "sparkle.magnifyingglass")
            CompactPanel(title: "对象存储", text: "未配置 · S3 / R2 / WebDAV", systemImage: "externaldrive")
            CompactPanel(title: "本地优先", text: "照片、记录和 API Key 默认不发送。", systemImage: "lock")
        }
    }
}

private struct PhoneContextHeader: View {
    let languageSpace: LanguageSpacePreview
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(languageSpace.displayContext, systemImage: "text.badge.star")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LangoTraceDesign.ColorToken.paleTeal)
                    .clipShape(Capsule())
                Spacer(minLength: 10)
            }
            Label(statusText, systemImage: "lock")
                .font(.footnote.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .accessibilityLabel(statusText)
        }
    }
}

private struct HeroActionCard: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("今天记录一点生活")
                    .font(.system(.title2, design: .default, weight: .semibold))
                Text("写一句、拍一张照片，或把今天想说的话留给之后的 \(languageSpace.targetLanguage) 练习。")
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                ActionChip(title: "写一句", systemImage: "pencil")
                ActionChip(title: "拍照", systemImage: "camera")
                ActionChip(title: "听一句", systemImage: "play")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 20)
        .langoSoftShadow()
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
        .padding(.top, 4)
    }
}

private struct ActionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Button {} label: {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
        }
        .buttonStyle(.plain)
        .background(LangoTraceDesign.ColorToken.paleTeal)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(title)
    }
}

private struct CompactPanel: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.paleTeal)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 16)
    }
}

private struct SampleEntryCard: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("雨天咖啡馆")
                        .font(.headline)
                    Text("照片写作 · \(languageSpace.targetLanguage) · 今天")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    InlineStatusLabel(text: "跟读 2 句", systemImage: "waveform")
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                }
            }

            Text("今天在咖啡馆坐了很久。外面一直下小雨，我没有急着回家。")
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("I spent a long time at the cafe today. It kept drizzling outside, and I was in no hurry to go home.")
                .font(.callout.weight(.medium))
                .lineSpacing(3)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .langoPanel()
        .accessibilityElement(children: .combine)
    }
}

private struct InlineStatusLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.teal)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(LangoTraceDesign.ColorToken.paleTeal)
            .clipShape(Capsule())
    }
}
