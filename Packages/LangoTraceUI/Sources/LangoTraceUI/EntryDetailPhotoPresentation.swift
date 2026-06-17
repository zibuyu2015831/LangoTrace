import CoreGraphics
import LangoTraceData

enum EntryDetailPhotoImageSizing: Equatable {
    case fit
}

struct EntryDetailPhotoLayout: Equatable {
    var imageSizing: EntryDetailPhotoImageSizing
    var hasVisibleChrome: Bool
    var maximumImageHeight: CGFloat

    static let loadedCard = EntryDetailPhotoLayout(
        imageSizing: .fit,
        hasVisibleChrome: true,
        maximumImageHeight: 280
    )
}

enum EntryDetailPhotoPresentation: Equatable {
    case notApplicable
    case loading
    case loaded
    case unavailable
    case failed

    static func initialState(for entry: LearningEntry) -> EntryDetailPhotoPresentation {
        entry.source == .photoWriting ? .loading : .notApplicable
    }

    static func resolvedState(
        photoDataWasLoaded: Bool,
        imageWasDecoded: Bool = true
    ) -> EntryDetailPhotoPresentation {
        guard photoDataWasLoaded else {
            return .unavailable
        }
        return imageWasDecoded ? .loaded : .failed
    }

    var shouldRenderRegion: Bool {
        self != .notApplicable
    }

    var titleKey: String? {
        switch self {
        case .notApplicable, .loaded:
            nil
        case .loading:
            "entry.detail.photo.loading.title"
        case .unavailable:
            "entry.detail.photo.unavailable.title"
        case .failed:
            "entry.detail.photo.failed.title"
        }
    }

    var summaryKey: String? {
        switch self {
        case .notApplicable, .loaded:
            nil
        case .loading:
            "entry.detail.photo.loading.summary"
        case .unavailable:
            "entry.detail.photo.unavailable.summary"
        case .failed:
            "entry.detail.photo.failed.summary"
        }
    }
}
