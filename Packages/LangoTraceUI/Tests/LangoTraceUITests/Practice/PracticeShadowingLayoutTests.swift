@testable import LangoTraceUI
import Testing

@Suite("Practice shadowing layout")
struct PracticeShadowingLayoutTests {
    @Test("No active session hides the control deck and centers the stage")
    func noContentHidesControlDeckAndCentersStage() {
        let layout = PracticeShadowingLayout.resolve(hasSession: false, hasVisibleFailure: false)

        #expect(layout.rendersControlDeck == false)
        #expect(layout.stageAlignment == .center)
    }

    @Test("Active session centers the stage and docks the control deck")
    func activeSessionCentersStageAndDocksControls() {
        let layout = PracticeShadowingLayout.resolve(hasSession: true, hasVisibleFailure: false)

        #expect(layout.rendersControlDeck)
        #expect(layout.stageAlignment == .center)
    }

    @Test("Visible failure top-aligns the stage so the message stays visible")
    func visibleFailureTopAlignsStage() {
        let layout = PracticeShadowingLayout.resolve(hasSession: true, hasVisibleFailure: true)

        #expect(layout.rendersControlDeck)
        #expect(layout.stageAlignment == .top)
    }
}
