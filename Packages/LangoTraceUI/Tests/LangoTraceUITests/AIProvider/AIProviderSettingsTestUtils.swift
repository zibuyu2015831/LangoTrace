import Foundation

func langoTraceUIPackageRootURL(currentFilePath: String = #filePath) -> URL {
    var url = URL(fileURLWithPath: currentFilePath)
    while url.lastPathComponent != "LangoTraceUI" {
        let parent = url.deletingLastPathComponent()
        precondition(parent.path != url.path, "Could not locate LangoTraceUI package root")
        url = parent
    }
    return url
}

func langoTraceUISourceFileURL(named fileName: String, currentFilePath: String = #filePath) -> URL {
    langoTraceUIPackageRootURL(currentFilePath: currentFilePath)
        .appendingPathComponent("Sources")
        .appendingPathComponent("LangoTraceUI")
        .appendingPathComponent(fileName)
}

func langoTraceAppSourceFileURL(named fileName: String, currentFilePath: String = #filePath) -> URL {
    langoTraceUIPackageRootURL(currentFilePath: currentFilePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("LangoTraceApp")
        .appendingPathComponent(fileName)
}
