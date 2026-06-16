import LangoTraceData

enum PhoneRoute: Hashable {
    case entryDetail(String)
    case readingDocument(String)
    case practiceSentenceList(String)
    case practiceSentence(PracticeSessionRouteSeed)
    case settings(SettingsCapability.Kind)
    case settingsList
}

enum PhoneSheet: Identifiable {
    case entryEditor
    case photoWritingPreview
    case languageSpaceSwitcher

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        case .photoWritingPreview:
            "photo-writing-preview"
        case .languageSpaceSwitcher:
            "language-space-switcher"
        }
    }
}
