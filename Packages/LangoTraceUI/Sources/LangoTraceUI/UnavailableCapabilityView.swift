import LangoTraceData
import SwiftUI

struct UnavailableCapabilityView: View {
    let content: UnavailableCapabilityContent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CapabilityStatusRow(
                localizedTitleKey: content.titleKey,
                localizedSummaryKey: content.summaryKey,
                status: .unavailable,
                systemImage: content.systemImage,
                action: nil
            )
            LocalizedTextPanel(
                titleKey: "unavailable.nextRequirement.title",
                textKey: content.nextRequirementKey
            )
            LocalizedTextPanel(
                titleKey: "unavailable.noSideEffects.title",
                textKey: "unavailable.noSideEffects.body"
            )
        }
        .padding(20)
        .langoPageBackground()
    }
}

struct UnavailableCapabilityContent: Equatable {
    let titleKey: String
    let summaryKey: String
    let nextRequirementKey: String
    let systemImage: String
}

extension UnavailableCapabilityContent {
    static let photoWriting = UnavailableCapabilityContent(
        titleKey: "unavailable.photoWriting.title",
        summaryKey: "unavailable.photoWriting.summary",
        nextRequirementKey: "unavailable.photoWriting.nextRequirement",
        systemImage: "camera"
    )

    static let listenOne = UnavailableCapabilityContent(
        titleKey: "unavailable.listenOne.title",
        summaryKey: "unavailable.listenOne.summary",
        nextRequirementKey: "unavailable.listenOne.nextRequirement",
        systemImage: "play"
    )

    static let languageSpace = UnavailableCapabilityContent(
        titleKey: "unavailable.languageSpace.title",
        summaryKey: "unavailable.languageSpace.summary",
        nextRequirementKey: "unavailable.languageSpace.nextRequirement",
        systemImage: "text.badge.star"
    )

    static let importExport = UnavailableCapabilityContent(
        titleKey: "unavailable.importExport.title",
        summaryKey: "unavailable.importExport.summary",
        nextRequirementKey: "unavailable.importExport.nextRequirement",
        systemImage: "tray.and.arrow.down"
    )

    static let search = UnavailableCapabilityContent(
        titleKey: "unavailable.search.title",
        summaryKey: "unavailable.search.summary",
        nextRequirementKey: "unavailable.search.nextRequirement",
        systemImage: "magnifyingglass"
    )

    static let vectorIndex = UnavailableCapabilityContent(
        titleKey: "unavailable.vectorIndex.title",
        summaryKey: "unavailable.vectorIndex.summary",
        nextRequirementKey: "unavailable.vectorIndex.nextRequirement",
        systemImage: "square.stack.3d.up"
    )

    static let generic = UnavailableCapabilityContent(
        titleKey: "unavailable.generic.title",
        summaryKey: "unavailable.generic.summary",
        nextRequirementKey: "unavailable.generic.nextRequirement",
        systemImage: "exclamationmark.circle"
    )
}
