import Foundation
@testable import LangoTraceCore
import Testing

/// Covers the LM02-S4b derive() hysteresis state machine (ADR-006 §10.1 contract):
/// the band must cross an adjacent tier for a sustained run of document-open
/// evaluations (stable threshold) before the effective level switches, and after
/// a switch must dwell before switching again — preventing the explanation tier
/// from drifting under the user's feet.
@Suite("Band hysteresis state machine")
struct BandHysteresisTests {
    @Test("a one-off / brief band fluctuation does not change the effective level")
    func bandFluctuationDoesNotImmediatelyChangeExplanationMode() {
        var hysteresis = BandHysteresis(seed: .b1)
        #expect(hysteresis.evaluate(bandLevel: .a2) == .b1) // 1st crossing
        #expect(hysteresis.evaluate(bandLevel: .a2) == .b1) // 2nd crossing — still < threshold
        #expect(hysteresis.effectiveLevel == .b1)
    }

    @Test("a sustained crossing changes the effective level after the stable threshold")
    func sustainedCrossingChangesModeAfterThreshold() {
        var hysteresis = BandHysteresis(seed: .b1)
        _ = hysteresis.evaluate(bandLevel: .a2)
        _ = hysteresis.evaluate(bandLevel: .a2)
        #expect(hysteresis.evaluate(bandLevel: .a2) == .a2) // 3rd consecutive — switches
        #expect(hysteresis.effectiveLevel == .a2)
    }

    @Test("a non-consecutive crossing resets the run (no switch)")
    func nonConsecutiveCrossingResets() {
        var hysteresis = BandHysteresis(seed: .b1)
        _ = hysteresis.evaluate(bandLevel: .a2)
        _ = hysteresis.evaluate(bandLevel: .b1) // back to seed — resets the run
        _ = hysteresis.evaluate(bandLevel: .a2)
        #expect(hysteresis.evaluate(bandLevel: .a2) == .b1) // only 2 consecutive since reset
        #expect(hysteresis.effectiveLevel == .b1)
    }

    @Test("after a switch, the dwell window prevents a rapid re-switch")
    func dwellWindowPreventsRapidReswitch() {
        var hysteresis = BandHysteresis(seed: .b1)
        // Switch down to a2 (3 consecutive crossings).
        _ = hysteresis.evaluate(bandLevel: .a2)
        _ = hysteresis.evaluate(bandLevel: .a2)
        #expect(hysteresis.evaluate(bandLevel: .a2) == .a2)
        // Now band wants b1 again; 4 consecutive crossings still inside the dwell
        // window (< 5 opens since the switch) must NOT switch back yet.
        for _ in 0 ..< 4 {
            #expect(hysteresis.evaluate(bandLevel: .b1) == .a2)
        }
        // The 5th open satisfies dwell → switches back to b1.
        #expect(hysteresis.evaluate(bandLevel: .b1) == .b1)
    }
}
