import LangoTraceCore
import Testing

@Suite("Practice exercise type contract")
struct PracticeExerciseTypeTests {
    @Test("Exercise type raw values match practice session storage contract")
    func exerciseTypeRawValuesMatchStorageContract() {
        #expect(PracticeExerciseType.allCases == [.shadowing, .dictation, .backtranslation])
        #expect(PracticeExerciseType.shadowing.rawValue == "shadowing")
        #expect(PracticeExerciseType.dictation.rawValue == "dictation")
        #expect(PracticeExerciseType.backtranslation.rawValue == "backtranslation")
    }
}
