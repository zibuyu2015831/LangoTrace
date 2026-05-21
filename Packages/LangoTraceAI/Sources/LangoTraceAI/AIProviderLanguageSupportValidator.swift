import Foundation
import LangoTraceCore
import NaturalLanguage

public struct AIProviderLanguageSupportValidationResult: Equatable, Sendable {
    public var isValid: Bool
    public var sample: String?
    public var errorCategory: AIProviderValidationErrorCategory?

    public init(
        isValid: Bool,
        sample: String?,
        errorCategory: AIProviderValidationErrorCategory?
    ) {
        self.isValid = isValid
        self.sample = sample
        self.errorCategory = errorCategory
    }
}

public struct AIProviderLanguageSupportValidator: Sendable {
    public init() {}

    public func validateResponseText(
        _ responseText: String,
        languageContext: AIProviderProbeLanguageContext
    ) -> AIProviderLanguageSupportValidationResult {
        guard let target = TargetLanguage(languageCode: languageContext.languageCode),
              let sample = parseSample(from: responseText),
              validateLength(sample, for: target),
              validateScript(sample, for: target),
              validateNaturalLanguage(sample, for: target)
        else {
            return AIProviderLanguageSupportValidationResult(
                isValid: false,
                sample: nil,
                errorCategory: .invalidResponse
            )
        }
        return AIProviderLanguageSupportValidationResult(
            isValid: true,
            sample: sample,
            errorCategory: nil
        )
    }
}

private extension AIProviderLanguageSupportValidator {
    enum TargetLanguage {
        case english
        case japanese
        case french
        case german
        case spanish
        case korean
        case simplifiedChinese

        init?(languageCode: String) {
            switch languageCode {
            case "en":
                self = .english
            case "ja":
                self = .japanese
            case "fr":
                self = .french
            case "de":
                self = .german
            case "es":
                self = .spanish
            case "ko":
                self = .korean
            case "zh-Hans":
                self = .simplifiedChinese
            default:
                return nil
            }
        }

        var nlLanguage: NLLanguage {
            switch self {
            case .english:
                .english
            case .japanese:
                .japanese
            case .french:
                .french
            case .german:
                .german
            case .spanish:
                .spanish
            case .korean:
                .korean
            case .simplifiedChinese:
                .simplifiedChinese
            }
        }

        var usesVisibleCharacterCount: Bool {
            switch self {
            case .japanese, .korean, .simplifiedChinese:
                true
            case .english, .french, .german, .spanish:
                false
            }
        }
    }

    func parseSample(from responseText: String) -> String? {
        let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("```"),
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object.count == 1,
              let sample = object["sample"] as? String
        else {
            return nil
        }
        let normalizedSample = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedSample.isEmpty ? nil : normalizedSample
    }

    func validateLength(_ sample: String, for target: TargetLanguage) -> Bool {
        if target.usesVisibleCharacterCount {
            let count = visibleCharacterCount(sample)
            return (45 ... 80).contains(count)
        }
        let count = wordCount(sample)
        return (40 ... 70).contains(count)
    }

    func visibleCharacterCount(_ sample: String) -> Int {
        sample.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !CharacterSet.punctuationCharacters.contains(scalar)
                && !CharacterSet.symbols.contains(scalar)
        }.count
    }

    func wordCount(_ sample: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = sample
        var count = 0
        tokenizer.enumerateTokens(in: sample.startIndex ..< sample.endIndex) { range, _ in
            let token = sample[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if token.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) {
                count += 1
            }
            return true
        }
        return count
    }

    func validateScript(_ sample: String, for target: TargetLanguage) -> Bool {
        let counts = ScriptCounts(sample)
        switch target {
        case .simplifiedChinese:
            return counts.cjk >= 30 && counts.latin < counts.cjk
        case .japanese:
            return counts.kana > 0
        case .korean:
            return counts.hangul > 0
        case .english, .french, .german, .spanish:
            return counts.latin >= 30 && counts.cjk == 0 && counts.kana == 0 && counts.hangul == 0
        }
    }

    func validateNaturalLanguage(_ sample: String, for target: TargetLanguage) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        if target == .simplifiedChinese {
            return hypotheses[.simplifiedChinese] != nil || hypotheses[.traditionalChinese] != nil
        }
        if target == .japanese || target == .korean {
            return hypotheses[target.nlLanguage] != nil || recognizer.dominantLanguage == target.nlLanguage
        }
        return (hypotheses[target.nlLanguage] ?? 0) >= 0.45 || recognizer.dominantLanguage == target.nlLanguage
    }
}

private struct ScriptCounts {
    var latin = 0
    var cjk = 0
    var kana = 0
    var hangul = 0

    init(_ sample: String) {
        for scalar in sample.unicodeScalars {
            switch scalar.value {
            case 0x0041 ... 0x005A, 0x0061 ... 0x007A, 0x00C0 ... 0x024F:
                latin += 1
            case 0x3040 ... 0x309F, 0x30A0 ... 0x30FF:
                kana += 1
            case 0x4E00 ... 0x9FFF:
                cjk += 1
            case 0x1100 ... 0x11FF, 0x3130 ... 0x318F, 0xAC00 ... 0xD7AF:
                hangul += 1
            default:
                continue
            }
        }
    }
}
