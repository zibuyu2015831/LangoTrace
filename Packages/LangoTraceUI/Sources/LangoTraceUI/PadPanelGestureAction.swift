import CoreGraphics

struct PadPanelGestureContext {
    let startX: CGFloat
    let translationX: CGFloat
    let translationY: CGFloat
    let workspaceWidth: CGFloat
    let isTimelineVisible: Bool
    let isLearningPanelVisible: Bool
}

enum PadPanelGestureAction: Equatable {
    case showTimeline
    case hideTimeline
    case showLearningPanel
    case hideLearningPanel

    static func action(
        in context: PadPanelGestureContext,
        edgeActivationWidth: CGFloat = 32,
        minimumHorizontalTranslation: CGFloat = 60,
        timelinePanelWidth: CGFloat = 300,
        learningPanelWidth: CGFloat = 360
    ) -> PadPanelGestureAction? {
        guard context.workspaceWidth > 0 else {
            return nil
        }

        let horizontalDistance = abs(context.translationX)
        let verticalDistance = abs(context.translationY)
        guard horizontalDistance >= minimumHorizontalTranslation,
              horizontalDistance > verticalDistance * 1.25
        else {
            return nil
        }

        if context.translationX > 0 {
            if !context.isTimelineVisible, context.startX <= edgeActivationWidth {
                return .showTimeline
            }
            if context.isLearningPanelVisible, context.startX >= context.workspaceWidth - learningPanelWidth {
                return .hideLearningPanel
            }
        }

        if context.translationX < 0 {
            if !context.isLearningPanelVisible, context.startX >= context.workspaceWidth - edgeActivationWidth {
                return .showLearningPanel
            }
            if context.isTimelineVisible, context.startX <= timelinePanelWidth {
                return .hideTimeline
            }
        }

        return nil
    }
}
