import Foundation
import LangoTraceData

final class SharedAppDatabaseFactory: @unchecked Sendable {
    private let lock = NSLock()
    private let databaseURLOverride: URL?
    private var cachedDatabase: AppDatabase?

    init(databaseURL: URL? = nil) {
        databaseURLOverride = databaseURL
    }

    func database() throws -> AppDatabase {
        lock.lock()
        defer { lock.unlock() }

        if let cachedDatabase {
            return cachedDatabase
        }
        let databaseURL = try databaseURLOverride ?? LanguageSpaceDatabaseLocation.defaultDatabaseURL()
        let database = try AppDatabase.persistent(at: databaseURL)
        cachedDatabase = database
        return database
    }
}
