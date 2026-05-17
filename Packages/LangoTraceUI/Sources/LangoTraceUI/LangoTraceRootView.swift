import LangoTraceCore
import SwiftUI

#if os(macOS)
    import AppKit
#endif

#if os(iOS)
    import UIKit
#endif

public struct LangoTraceRootView: View {
    public init() {}

    public var body: some View {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                PlatformRootPlaceholder(platformRole: .pad)
            } else {
                PlatformRootPlaceholder(platformRole: .phone)
            }
        #elseif os(macOS)
            PlatformRootPlaceholder(platformRole: .mac)
        #endif
    }
}

private struct PlatformRootPlaceholder: View {
    let platformRole: PlatformRole

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ProductIdentity.displayName)
                    .font(.system(size: titleSize, weight: .semibold, design: .default))

                Text(ProductIdentity.chineseSlogan)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(ProductIdentity.englishSlogan)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(platformTitle)
                    .font(.headline)

                Text(platformDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(32)
        .frame(maxWidth: frameWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(backgroundColor)
    }

    private var titleSize: CGFloat {
        switch platformRole {
        case .phone:
            30
        case .pad:
            36
        case .mac:
            34
        }
    }

    private var frameWidth: CGFloat {
        switch platformRole {
        case .phone:
            420
        case .pad:
            680
        case .mac:
            760
        }
    }

    private var platformTitle: String {
        switch platformRole {
        case .phone:
            "iPhone App Shell"
        case .pad:
            "iPad App Shell"
        case .mac:
            "macOS App Shell"
        }
    }

    private var platformDescription: String {
        switch platformRole {
        case .phone:
            "为随手记录、拍照引导写作和碎片练习保留入口。"
        case .pad:
            "为沉浸写作、双语对照和学习面板保留布局空间。"
        case .mac:
            "为语言资料库、批量整理和高级配置保留桌面工作台边界。"
        }
    }

    private var backgroundColor: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #else
            Color(uiColor: .systemBackground)
        #endif
    }
}
