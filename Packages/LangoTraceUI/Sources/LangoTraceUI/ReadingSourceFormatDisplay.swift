import LangoTraceCore

extension ReadingSourceFormat {
    /// Human-readable display name for use in the reading library UI.
    /// Markdown, EPUB and PDF retain their standard product names unchanged.
    var displayName: String {
        switch self {
        case .pastedText:  return localizedString("reading.source.pastedText")
        case .plainText:   return localizedString("reading.source.plainText")
        case .markdown:    return "Markdown"
        case .epub:        return "EPUB"
        case .pdf:         return "PDF"
        case .htmlClip:    return localizedString("reading.source.htmlClip")
        case .webArticle:  return localizedString("reading.source.webArticle")
        }
    }
}
