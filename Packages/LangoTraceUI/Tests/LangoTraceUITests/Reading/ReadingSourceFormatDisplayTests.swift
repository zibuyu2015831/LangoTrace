import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("ReadingSourceFormat displayName")
struct ReadingSourceFormatDisplayTests {
    @Test("All cases return non-rawValue display names")
    func allCasesReturnReadableName() {
        let cases: [ReadingSourceFormat] = [
            .pastedText, .plainText, .markdown, .epub, .pdf, .htmlClip, .webArticle,
        ]
        for sourceFormat in cases {
            let name = sourceFormat.displayName
            #expect(!name.isEmpty, "displayName should not be empty for \(sourceFormat)")
            #expect(
                name != sourceFormat.rawValue,
                "displayName '\(name)' should not equal rawValue for \(sourceFormat)"
            )
        }
    }

    @Test("Hardcoded format names are locale-independent")
    func hardcodedFormatNames() {
        // These cases use fixed product/standard names regardless of locale.
        #expect(ReadingSourceFormat.markdown.displayName == "Markdown")
        #expect(ReadingSourceFormat.epub.displayName == "EPUB")
        #expect(ReadingSourceFormat.pdf.displayName == "PDF")
    }
}
