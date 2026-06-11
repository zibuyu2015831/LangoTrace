import SwiftUI

struct WelcomeView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @ScaledMetric(relativeTo: .largeTitle) var wideValueTitleSize = LangoTraceDesign.Typography
        .welcomeWideTitleBaseSize
    @ScaledMetric(relativeTo: .largeTitle) var macValueTitleSize = LangoTraceDesign.Typography
        .welcomeMacHeroTitleBaseSize

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            LangoTraceDesign.ColorToken.paper.ignoresSafeArea()

            GeometryReader { proxy in
                #if os(macOS)
                    if usesWideLayout(in: proxy.size) {
                        ScrollView {
                            macWideContent(size: proxy.size)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        compactContentWithBottomAction(size: proxy.size)
                    }
                #else
                    if usesWideLayout(in: proxy.size), iPadAllowsWideLayout(in: proxy.size) {
                        ScrollView {
                            wideContent(size: proxy.size)
                        }
                        .scrollIndicators(.hidden)
                    } else if usesPadPortraitLayout(in: proxy.size) {
                        ScrollView {
                            padPortraitContent(size: proxy.size)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        compactContentWithBottomAction(size: proxy.size)
                    }
                #endif
            }
        }
    }
}
