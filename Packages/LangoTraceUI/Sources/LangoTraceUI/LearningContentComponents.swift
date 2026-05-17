import LangoTraceData
import SwiftUI

struct EntryTimelineRow: View {
    let entry: LearningEntry
    let targetLanguage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(isSelected ? LangoTraceDesign.ColorToken.accent : LangoTraceDesign.ColorToken.borderSubtle)
                    .frame(width: 8, height: 8)
                    .padding(.top, 7)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    Text("\(entry.sourceTitle) · \(targetLanguage) · \(entry.scene)")
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Text(entry.practiceSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? LangoTraceDesign.ColorToken.surfaceRaised : .clear)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                    .stroke(isSelected ? LangoTraceDesign.ColorToken.accent.opacity(0.35) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title)，\(entry.sourceTitle)，\(entry.practiceSummary)")
        .accessibilityValue(isSelected ? "当前选中" : "未选中")
    }
}

struct SideItem: View {
    let title: String
    let subtitle: String
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? LangoTraceDesign.ColorToken.surfaceRaised : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                .stroke(active ? LangoTraceDesign.ColorToken.accent.opacity(0.25) : Color.clear, lineWidth: 1)
        }
    }
}

struct SentencePairView: View {
    let index: Int
    let sentence: RenderingSentence
    let onPractice: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(sentence.translation)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                Text(sentence.targetText)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                Text(sentence.note)
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("听") {}
                    .buttonStyle(.bordered)
                    .accessibilityHint("当前为本地 mock，不播放真实语音")
                Button("练", action: onPractice)
                    .buttonStyle(.borderedProminent)
            }
        }
        .langoPanel()
    }
}

struct RequestPreviewCard: View {
    let entry: LearningEntry
    let rendering: LearningRendering?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("请求预览", systemImage: "eye")
                .font(.headline)
            Text(sentContent)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("不会发送：本地数据库、完整照片库、API Key、未选中的历史记录。")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("当前使用 Local Mock，不会触发外部 AI 请求。", systemImage: "lock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.privacyLocal)
        }
        .langoPanel()
    }

    private var sentContent: String {
        if let rendering {
            "即将发送：\(entry.title)、选中的正文片段、Prompt \(rendering.promptLabel)。"
        } else {
            "即将发送：\(entry.title)、选中的正文片段、生成意图。"
        }
    }
}

struct InlineStatusLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
            .clipShape(Capsule())
    }
}

struct TextPanel: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
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
    private static let waveformHeights = [24, 38, 28, 46, 40, 32, 26, 38, 46, 20]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("朗读音频", systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                Spacer()
                Text("0.85x")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            HStack(alignment: .center, spacing: 5) {
                ForEach(Self.waveformHeights.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LangoTraceDesign.ColorToken.accent.opacity(0.45))
                        .frame(width: 8, height: CGFloat(Self.waveformHeights[index]))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .langoPanel()
    }
}
