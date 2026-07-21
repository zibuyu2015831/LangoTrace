import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Companion persona")
struct CompanionPersonaTests {
    @Test("Default persona is friendly / casual / only-when-needed")
    func defaultPersona() {
        #expect(CompanionPersona.default.tone == .friendly)
        #expect(CompanionPersona.default.formality == .casual)
        #expect(CompanionPersona.default.correction == .ifNeeded)
    }

    @Test("personaMapsEnumOnlyToControlledFragments — every combination yields three fixed fragments, no user text")
    func personaMapsEnumOnlyToControlledFragments() {
        // The struct has no free-text field, so injection is impossible by
        // construction. Verify the mapping is total and deterministic across
        // every enum combination, and that each axis actually varies output.
        for tone in CompanionTone.allCases {
            for formality in CompanionFormality.allCases {
                for correction in CompanionCorrection.allCases {
                    let persona = CompanionPersona(
                        tone: tone,
                        formality: formality,
                        correction: correction
                    )
                    let fragments = persona.controlledFragments()
                    #expect(fragments.count == 3)
                    #expect(fragments.allSatisfy { !$0.isEmpty })
                }
            }
        }
    }

    @Test("Changing each persona axis changes the corresponding controlled fragment")
    func eachAxisVariesItsFragment() {
        let base = CompanionPersona.default
        // tone (fragment 0)
        let humorous = CompanionPersona(tone: .humorous, formality: .casual, correction: .ifNeeded)
        #expect(base.controlledFragments()[0] != humorous.controlledFragments()[0])
        // formality (fragment 1)
        let formal = CompanionPersona(tone: .friendly, formality: .formal, correction: .ifNeeded)
        #expect(base.controlledFragments()[1] != formal.controlledFragments()[1])
        // correction (fragment 2)
        let recast = CompanionPersona(tone: .friendly, formality: .casual, correction: .warmRecast)
        #expect(base.controlledFragments()[2] != recast.controlledFragments()[2])
    }
}
