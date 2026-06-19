import SwiftUI

public struct PhotoDisplayActions: Sendable {
    public var loadPhotoData: @Sendable (_ entryID: String) async -> Data?

    public init(loadPhotoData: @escaping @Sendable (String) async -> Data?) {
        self.loadPhotoData = loadPhotoData
    }

    public static let disabled = PhotoDisplayActions(loadPhotoData: { _ in nil })
}

public extension EnvironmentValues {
    @Entry var photoDisplayActions = PhotoDisplayActions.disabled
}
