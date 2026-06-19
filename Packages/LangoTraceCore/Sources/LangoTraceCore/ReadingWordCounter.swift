import Foundation

public enum ReadingWordCounter {
    private static let cjkLanguagePrefixes: Set<String> = ["zh", "ja", "ko"]

    /// Returns approximate word count for display in the reading library row.
    /// CJK languages count characters; all others split on whitespace.
    public static func wordCount(for text: String, languageCode: String) -> Int {
        let prefix = String(languageCode.prefix(2))
        if cjkLanguagePrefixes.contains(prefix) {
            return text.unicodeScalars.count(where: { !$0.properties.isWhitespace })
        }
        return text.split(whereSeparator: \.isWhitespace).count(where: { !$0.isEmpty })
    }
}
