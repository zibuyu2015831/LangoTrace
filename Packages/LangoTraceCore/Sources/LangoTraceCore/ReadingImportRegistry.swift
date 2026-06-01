public enum ReadingImportAdapterStatus: String, Equatable, Hashable, Sendable {
    case enabled
    case future
}

public struct ReadingImportAdapterDescriptor: Equatable, Hashable, Sendable {
    public var id: String
    public var version: Int
    public var sourceFormat: ReadingSourceFormat
    public var supportedFileExtensions: [String]
    public var status: ReadingImportAdapterStatus

    public init(
        id: String,
        version: Int,
        sourceFormat: ReadingSourceFormat,
        supportedFileExtensions: [String],
        status: ReadingImportAdapterStatus
    ) {
        self.id = id
        self.version = version
        self.sourceFormat = sourceFormat
        self.supportedFileExtensions = supportedFileExtensions
        self.status = status
    }
}

public struct ReadingImportFormatRegistry: Sendable {
    private var enabledAdapters: [ReadingImportAdapterDescriptor]

    public init(enabledAdapters: [ReadingImportAdapterDescriptor]) {
        self.enabledAdapters = enabledAdapters
    }

    public static func verticalSliceDefaults() -> ReadingImportFormatRegistry {
        ReadingImportFormatRegistry(enabledAdapters: [
            ReadingImportAdapterDescriptor(
                id: "pasted-text.v1",
                version: 1,
                sourceFormat: .pastedText,
                supportedFileExtensions: [],
                status: .enabled
            ),
            ReadingImportAdapterDescriptor(
                id: "plain-text-file.v1",
                version: 1,
                sourceFormat: .plainText,
                supportedFileExtensions: ["txt"],
                status: .enabled
            ),
            ReadingImportAdapterDescriptor(
                id: "markdown-file.v1",
                version: 1,
                sourceFormat: .markdown,
                supportedFileExtensions: ["md"],
                status: .enabled
            ),
        ])
    }

    public static func futureAdapterDescriptors() -> [ReadingImportAdapterDescriptor] {
        [
            ReadingImportAdapterDescriptor(
                id: "epub-text-extraction.v1",
                version: 1,
                sourceFormat: .epub,
                supportedFileExtensions: ["epub"],
                status: .future
            ),
            ReadingImportAdapterDescriptor(
                id: "pdf-text-extraction.v1",
                version: 1,
                sourceFormat: .pdf,
                supportedFileExtensions: ["pdf"],
                status: .future
            ),
            ReadingImportAdapterDescriptor(
                id: "html-clip.v1",
                version: 1,
                sourceFormat: .htmlClip,
                supportedFileExtensions: ["html", "htm"],
                status: .future
            ),
        ]
    }

    public func adapter(for sourceFormat: ReadingSourceFormat) -> ReadingImportAdapterDescriptor? {
        enabledAdapters.first { $0.sourceFormat == sourceFormat && $0.status == .enabled }
    }

    public func adapter(forFileExtension fileExtension: String) -> ReadingImportAdapterDescriptor? {
        let normalized = fileExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return enabledAdapters.first {
            $0.status == .enabled && $0.supportedFileExtensions.contains(normalized)
        }
    }
}
