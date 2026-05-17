import LangoTraceAI
import LangoTraceData
import LangoTraceSpeech
import LangoTraceSync
import LangoTraceUI
import SwiftUI

@main
struct LangoTraceApp: App {
    private let environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            LangoTraceRootView()
                .environment(\.appEnvironment, environment)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
