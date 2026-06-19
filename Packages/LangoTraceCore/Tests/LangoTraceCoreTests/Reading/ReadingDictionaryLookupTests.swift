@testable import LangoTraceCore
import Testing

@Suite("Reading dictionary lookup")
struct ReadingDictionaryLookupTests {
    @Test("exact lookup uses normalized form and language code")
    func exactLookupUsesNormalization() {
        let entries = [
            ReadingDictionaryEntry(headword: "Résumé", languageCode: "fr", definition: "summary"),
            ReadingDictionaryEntry(headword: "resume", languageCode: "en", definition: "continue"),
        ]
        let index = ReadingDictionaryLookupIndex(entries: entries)

        #expect(index.exactLookup("résumé", languageCode: "fr").first?.definition == "summary")
        #expect(index.exactLookup("resume", languageCode: "en").first?.definition == "continue")
    }

    @Test("synthetic 100k lookup returns deterministic result")
    func syntheticLargeLookup() {
        let entries = (0 ..< 100_000).map { index in
            ReadingDictionaryEntry(
                headword: "word\(index)",
                languageCode: "en",
                definition: "definition \(index)"
            )
        }

        let lookup = ReadingDictionaryLookupIndex(entries: entries)

        #expect(lookup.exactLookup("word99999", languageCode: "en").first?.definition == "definition 99999")
        #expect(lookup.exactLookup("missing", languageCode: "en").isEmpty)
    }
}
