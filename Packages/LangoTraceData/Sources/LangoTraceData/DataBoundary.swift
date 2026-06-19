import LangoTraceCore

public protocol LanguageSpaceRepository: Sendable {
    func listActiveLanguageSpaces() throws -> [LanguageSpace]
    func languageSpace(id: String) throws -> LanguageSpace?
    func currentLanguageSpace() throws -> LanguageSpace?
    func createLanguageSpace(input: CreateLanguageSpaceInput) throws -> LanguageSpace
    func updateLanguageSpace(id: String, input: UpdateLanguageSpaceInput) throws -> LanguageSpace
    func selectCurrentLanguageSpace(id: String) throws -> LanguageSpace
    func deleteLanguageSpace(id: String) throws -> LanguageSpaceDeletionResult
    func duplicateNameExists(displayName: String, excludingID: String?) throws -> Bool
}

public struct EmptyLanguageSpaceRepository: LanguageSpaceRepository {
    public init() {}

    public func listActiveLanguageSpaces() throws -> [LanguageSpace] {
        []
    }

    public func languageSpace(id _: String) throws -> LanguageSpace? {
        nil
    }

    public func currentLanguageSpace() throws -> LanguageSpace? {
        nil
    }

    public func createLanguageSpace(input _: CreateLanguageSpaceInput) throws -> LanguageSpace {
        throw LanguageSpaceError.storageUnavailable
    }

    public func updateLanguageSpace(id _: String, input _: UpdateLanguageSpaceInput) throws -> LanguageSpace {
        throw LanguageSpaceError.storageUnavailable
    }

    public func selectCurrentLanguageSpace(id _: String) throws -> LanguageSpace {
        throw LanguageSpaceError.storageUnavailable
    }

    public func deleteLanguageSpace(id _: String) throws -> LanguageSpaceDeletionResult {
        throw LanguageSpaceError.storageUnavailable
    }

    public func duplicateNameExists(displayName _: String, excludingID _: String?) throws -> Bool {
        false
    }
}
