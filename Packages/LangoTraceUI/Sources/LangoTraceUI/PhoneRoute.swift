import LangoTraceData

enum PhoneRoute: Hashable {
    case entryDetail(String)
    case bilingualReading(String)
    case readingDocument(String)
    case practiceSentenceList(String)
    case practiceSentence(PracticeSessionRouteSeed)
    case settings(SettingsCapability.Kind)
    case settingsList
}

enum PhoneSheet: Identifiable {
    case entryEditor
    case photoWriting
    case languageSpaceSwitcher

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        case .photoWriting:
            "photo-writing"
        case .languageSpaceSwitcher:
            "language-space-switcher"
        }
    }
}
