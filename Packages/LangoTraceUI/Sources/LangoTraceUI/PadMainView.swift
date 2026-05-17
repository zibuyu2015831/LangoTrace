import LangoTraceCore
import SwiftUI

struct PadMainView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            writingDesk
            Divider()
            learningPanel
        }
        .langoPageBackground()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LEARNING LANGUAGE")
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            LanguageSpaceBadge(languageSpace: languageSpace)
            Text("TIMELINE")
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            SideItem(title: "雨天咖啡馆", subtitle: "照片写作 · 英语 · 今天", active: true)
            SideItem(title: "写给朋友的感谢", subtitle: "正式表达 · 昨天", active: false)
            Spacer()
            Button {} label: {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .frame(width: 280, alignment: .topLeading)
    }

    private var writingDesk: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("雨天咖啡馆")
                            .font(.largeTitle.weight(.semibold))
                        Text("中文记录转换为英语学习材料，支持逐句朗读、解释、跟读、听写和回译。")
                            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    }
                    Spacer()
                    Text(languageSpace.displayContext)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(LangoTraceDesign.ColorToken.paleTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                HStack(alignment: .top, spacing: 14) {
                    TextPanel(
                        title: "ORIGINAL",
                        text: "今天在咖啡馆坐了很久。外面一直下小雨，我没有急着回家，只是听着雨声，看窗外的人来来往往。"
                    )
                    TextPanel(
                        title: "TARGET",
                        text: """
                        I spent a long time at the cafe today. It kept drizzling outside, \
                        and I was in no hurry to go home. I just listened to the rain and \
                        watched people passing by outside the window.
                        """
                    )
                }
                AudioPanel()
                SentenceRow(
                    index: 1,
                    text: "I spent a long time at the cafe today.",
                    translation: "今天在咖啡馆坐了很久。"
                )
                SentenceRow(
                    index: 2,
                    text: "I just listened to the rain and watched people passing by outside the window.",
                    translation: "我只是听着雨声，看窗外的人来来往往。"
                )
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }

    private var learningPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LEARNING PANEL")
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            TextPanel(title: "当前句讲解", text: "spent a long time 比 stayed for a long time 更自然地表达“度过一段时间”。")
            TextPanel(title: "词句提取", text: "drizzling, in no hurry, listened to the rain, watched people passing by.")
            TextPanel(title: "练习入口", text: "听写 3 句 · 回译 3 句 · 跟读录音 2 轮。")
            Spacer()
        }
        .padding(22)
        .frame(width: 330, alignment: .topLeading)
    }
}

struct LanguageSpaceBadge: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(languageSpace.name)
                .font(.headline)
            Text(languageSpace.displayContext)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
    }
}

struct SideItem: View {
    let title: String
    let subtitle: String
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
        .overlay {
            RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.panel, style: .continuous)
                .stroke(active ? LangoTraceDesign.ColorToken.teal.opacity(0.5) : .clear, lineWidth: 1.5)
        }
    }
}

struct TextPanel: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .langoPanel()
    }
}

struct AudioPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AUDIO")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                Spacer()
                Text("0.85x")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            HStack(alignment: .center, spacing: 5) {
                ForEach([24, 38, 28, 46, 40, 32, 26, 38, 46, 20], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LangoTraceDesign.ColorToken.teal.opacity(0.45))
                        .frame(width: 8, height: CGFloat(height))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(LangoTraceDesign.ColorToken.paleTeal)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .langoPanel()
    }
}

private struct SentenceRow: View {
    let index: Int
    let text: String
    let translation: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.paleTeal)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(translation)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                Text(text)
                    .font(.headline)
            }
            Spacer()
            Button("听") {}
                .buttonStyle(.bordered)
        }
        .langoPanel()
    }
}
