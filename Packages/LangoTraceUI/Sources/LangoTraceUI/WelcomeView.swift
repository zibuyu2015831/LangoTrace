import LangoTraceCore
import SwiftUI

struct WelcomeView: View {
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            LangoTraceDesign.ColorToken.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 44)
                brandBlock
                statusStrip
                Spacer(minLength: 28)
                entryBlock
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 36)
            .frame(maxWidth: 640, maxHeight: .infinity, alignment: .leading)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(650))
            onFinished()
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(LangoTraceDesign.ColorToken.gold)
                    .frame(width: 8, height: 8)
                Text("LANGOTRACE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            Text(ProductIdentity.displayName)
                .font(.system(size: 42, weight: .semibold, design: .default))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: 6) {
                Text(ProductIdentity.chineseSlogan)
                    .font(.title3.weight(.medium))
                Text(ProductIdentity.englishSlogan)
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            CapsuleLabel(text: "本地优先", systemImage: "lock")
            CapsuleLabel(text: "未配置 AI", systemImage: "sparkle.magnifyingglass")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("本地优先，未配置 AI")
    }

    private var entryBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("今天记录一点生活")
                .font(.title2.weight(.semibold))
            Text("正在准备你的语言空间。首次使用会先询问母语、目标语言和水平自评。")
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            ProgressView()
                .controlSize(.small)
                .padding(.top, 4)
        }
        .langoPanel(padding: 22)
    }
}

private struct CapsuleLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LangoTraceDesign.ColorToken.paleTeal)
            .clipShape(Capsule())
    }
}
