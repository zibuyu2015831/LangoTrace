import LangoTraceData
import SwiftUI

enum CapabilityStatusTone: String, Equatable {
    case ready
    case localMock
    case unavailable
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

struct RequestPreviewCopy: Equatable {
    let body: String

    static func localMock(entryTitle: String, promptLabel: String?) -> RequestPreviewCopy {
        let prompt = promptLabel ?? "生成意图"
        return RequestPreviewCopy(
            body: "真实接入后会请求确认：\(entryTitle)、选中的正文片段、Prompt \(prompt)。当前不会发送外部请求。"
        )
    }

    static func externalRequest(entryTitle: String, promptLabel: String?) -> RequestPreviewCopy {
        let prompt = promptLabel ?? "生成意图"
        return RequestPreviewCopy(
            body: "将发送：\(entryTitle)、选中的正文片段、Prompt \(prompt)。"
        )
    }
}

struct PadPanelVisibility: Equatable {
    var timeline: Bool
    var learningPanel: Bool
}

enum PadAdaptivePanelLayout {
    static func visibility(
        for horizontalSizeClass: UserInterfaceSizeClass?,
        current: PadPanelVisibility
    ) -> PadPanelVisibility {
        guard horizontalSizeClass == .compact else {
            return current
        }

        return PadPanelVisibility(timeline: current.timeline, learningPanel: false)
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
