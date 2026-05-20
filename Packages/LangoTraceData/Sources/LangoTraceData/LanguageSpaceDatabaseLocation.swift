import Foundation
import LangoTraceCore

public enum LanguageSpaceDatabaseLocation {
    public static func defaultDatabaseURL(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LanguageSpaceError.storageUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent("LangoTrace", isDirectory: true)
            .appendingPathComponent("LangoTrace.sqlite", isDirectory: false)
    }
}
