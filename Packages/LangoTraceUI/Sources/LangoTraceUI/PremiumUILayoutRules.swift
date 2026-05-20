import LangoTraceData
import SwiftUI

enum CapabilityStatusTone: String, Equatable {
    case ready
    case localMock
    case unavailable
    case warning
    case error
    case info
}

extension CapabilityStatus {
    var visualTone: CapabilityStatusTone {
        switch self {
        case .ready:
            .ready
        case .mockOnly:
            .localMock
        case .unavailable:
            .unavailable
        }
    }
}

enum LangoTraceStatusKind: String, CaseIterable, Equatable {
    case ready
    case localPreview
    case unavailable
    case warning
    case error
    case permissionDenied
    case syncConflict
    case loading

    var titleKey: String {
        "status.\(rawValue).title"
    }

    var summaryKey: String {
        "status.\(rawValue).summary"
    }

    var systemImage: String {
        switch self {
        case .ready:
            "checkmark.circle"
        case .localPreview:
            "sparkles"
        case .unavailable:
            "lock"
        case .warning:
            "exclamationmark.triangle"
        case .error:
            "xmark.octagon"
        case .permissionDenied:
            "hand.raised"
        case .syncConflict:
            "arrow.triangle.branch"
        case .loading:
            "clock"
        }
    }

    var visualTone: CapabilityStatusTone {
        switch self {
        case .ready:
            .ready
        case .localPreview:
            .localMock
        case .unavailable:
            .unavailable
        case .warning, .permissionDenied:
            .warning
        case .error, .syncConflict:
            .error
        case .loading:
            .info
        }
    }
}

struct RequestPreviewCopy: Equatable {
    let body: String

    static func localMock(entryTitle: String, promptLabel: String?) -> RequestPreviewCopy {
        let prompt = promptLabel ?? localizedString("requestPreview.promptFallback")
        return RequestPreviewCopy(
            body: localizedString("requestPreview.localMock.body", entryTitle, prompt)
        )
    }

    static func externalRequest(entryTitle: String, promptLabel: String?) -> RequestPreviewCopy {
        let prompt = promptLabel ?? localizedString("requestPreview.promptFallback")
        return RequestPreviewCopy(
            body: localizedString("requestPreview.external.body", entryTitle, prompt)
        )
    }
}

struct PadPanelVisibility: Equatable {
    var timeline: Bool
    var learningPanel: Bool
}

enum PadWorkspaceWidthClass: Equatable {
    case singleColumn
    case twoColumn
    case threeColumn

    static func classify(width: CGFloat) -> PadWorkspaceWidthClass {
        if width < 700 {
            return .singleColumn
        }

        if width < 980 {
            return .twoColumn
        }

        return .threeColumn
    }
}

enum PadAdaptivePanelLayout {
    static func visibility(
        for horizontalSizeClass: UserInterfaceSizeClass?,
        current: PadPanelVisibility
    ) -> PadPanelVisibility {
        visibility(forWidth: nil, horizontalSizeClass: horizontalSizeClass, current: current)
    }

    static func visibility(
        forWidth width: CGFloat?,
        horizontalSizeClass: UserInterfaceSizeClass?,
        current: PadPanelVisibility
    ) -> PadPanelVisibility {
        guard horizontalSizeClass == .compact else {
            guard let width else {
                return current
            }

            switch PadWorkspaceWidthClass.classify(width: width) {
            case .threeColumn:
                return current
            case .twoColumn:
                return PadPanelVisibility(timeline: current.timeline, learningPanel: false)
            case .singleColumn:
                return PadPanelVisibility(timeline: false, learningPanel: false)
            }
        }

        return PadPanelVisibility(timeline: current.timeline, learningPanel: false)
    }
}

enum PadSettingsFocusPolicy {
    static func visibility(
        whenEntering route: PadWorkspaceRoute,
        current: PadPanelVisibility
    ) -> PadPanelVisibility {
        guard route.isSettingsDetail else {
            return current
        }

        return PadPanelVisibility(timeline: current.timeline, learningPanel: false)
    }

    static func visibilityAfterResize(
        route: PadWorkspaceRoute,
        workspaceWidth: CGFloat?,
        horizontalSizeClass: UserInterfaceSizeClass?,
        current: PadPanelVisibility
    ) -> PadPanelVisibility {
        let adaptive = PadAdaptivePanelLayout.visibility(
            forWidth: workspaceWidth,
            horizontalSizeClass: horizontalSizeClass,
            current: current
        )

        guard route.isSettingsDetail,
              horizontalSizeClass != .compact,
              PadWorkspaceWidthClass.classify(width: workspaceWidth ?? 980) == .threeColumn
        else {
            return adaptive
        }

        return current
    }
}

private extension PadWorkspaceRoute {
    var isSettingsDetail: Bool {
        switch self {
        case .settings:
            true
        case .workspace, .entryDetail, .practice, .settingsList, .memory, .importExport, .languageSpaceManagement:
            false
        }
    }
}

enum MacWindowLayout {
    static func minimumWidth(sidebarVisible: Bool, inspectorVisible: Bool) -> CGFloat {
        switch (sidebarVisible, inspectorVisible) {
        case (true, true):
            1040
        case (true, false):
            820
        case (false, true):
            780
        case (false, false):
            560
        }
    }
}

enum EntryRenderingStatus {
    static func status(for rendering: LearningRendering?) -> CapabilityStatus {
        guard let rendering else {
            return .unavailable
        }

        return rendering.isMock ? .mockOnly : .ready
    }
}
