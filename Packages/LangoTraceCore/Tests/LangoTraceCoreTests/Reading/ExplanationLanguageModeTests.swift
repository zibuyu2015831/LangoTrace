import LangoTraceCore
import Testing

@Suite("ExplanationLanguageMode derivation")
struct ExplanationLanguageModeTests {
    @Test("A1 and A2 derive to sourceLanguage")
    func a1a2DeriveToSourceLanguage() {
        #expect(ExplanationLanguageMode.derive(from: "A1") == .sourceLanguage)
        #expect(ExplanationLanguageMode.derive(from: "A2") == .sourceLanguage)
    }

    @Test("B1 and B2 derive to bilingualBridge")
    func b1b2DeriveToBilingualBridge() {
        #expect(ExplanationLanguageMode.derive(from: "B1") == .bilingualBridge)
        #expect(ExplanationLanguageMode.derive(from: "B2") == .bilingualBridge)
    }

    @Test("C1 and C2 derive to targetImmersion")
    func c1c2DeriveToTargetImmersion() {
        #expect(ExplanationLanguageMode.derive(from: "C1") == .targetImmersion)
        #expect(ExplanationLanguageMode.derive(from: "C2") == .targetImmersion)
    }

    @Test("empty string falls back to bilingualBridge")
    func emptyStringFallsBackToBilingualBridge() {
        #expect(ExplanationLanguageMode.derive(from: "") == .bilingualBridge)
    }

    @Test("unknown level code falls back to bilingualBridge")
    func unknownLevelFallsBackToBilingualBridge() {
        #expect(ExplanationLanguageMode.derive(from: "ZZ") == .bilingualBridge)
        #expect(ExplanationLanguageMode.derive(from: "b1") == .bilingualBridge) // case-sensitive
    }

    @Test("all rawValues are stable string tokens")
    func rawValuesAreStableTokens() {
        #expect(ExplanationLanguageMode.sourceLanguage.rawValue == "sourceLanguage")
        #expect(ExplanationLanguageMode.bilingualBridge.rawValue == "bilingualBridge")
        #expect(ExplanationLanguageMode.targetImmersion.rawValue == "targetImmersion")
    }

    @Test("roundtrip through rawValue")
    func rawValueRoundtrip() {
        for mode in ExplanationLanguageMode.allCases {
            #expect(ExplanationLanguageMode(rawValue: mode.rawValue) == mode)
        }
    }
}
