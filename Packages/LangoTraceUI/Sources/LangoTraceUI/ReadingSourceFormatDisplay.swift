import LangoTraceCore

extension ReadingSourceFormat {
    /// Human-readable display name for use in the reading library UI.
    /// Markdown, EPUB and PDF retain their standard product names unchanged.
    var displayName: String {
        switch self {
        case .pastedText: localizedString("reading.source.pastedText")
        case .plainText: localizedString("reading.source.plainText")
        case .markdown: "Markdown"
        case .epub: "EPUB"
        case .pdf: "PDF"
        case .htmlClip: localizedString("reading.source.htmlClip")
        case .webArticle: localizedString("reading.source.webArticle")
        }
    }
}
