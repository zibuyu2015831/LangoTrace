import Foundation
#if canImport(NaturalLanguage)
    import NaturalLanguage
#endif

/// Local language detection seam for the Style provider. Injected so the
/// compute-on-read grouping / exclusion logic is deterministically testable
/// without depending on `NaturalLanguage` (which is Apple-only and unreliable on
/// short / non-natural text) — mirroring how the LM01 provider injects `clock`.
public protocol LanguageDetector: Sendable {
    /// Detects the dominant language of `text`, returning a BCP-47-ish code and a
    /// 0…1 confidence, or `nil` when no language could be determined.
    func detect(_ text: String) -> (language: String, confidence: Double)?
}

/// Default detector backed by `NLLanguageRecognizer`. Maps the recognizer's
/// dominant-language hypothesis to its code + probability.
public struct NaturalLanguageDetector: LanguageDetector {
    public init() {}

    public func detect(_ text: String) -> (language: String, confidence: Double)? {
        #if canImport(NaturalLanguage)
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            guard let language = recognizer.dominantLanguage else { return nil }
            let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
            let confidence = hypotheses[language] ?? 0
            return (language.rawValue, confidence)
        #else
            return nil
        #endif
    }
}
