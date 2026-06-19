import LangoTraceData
import SwiftUI

struct UnavailableCapabilityView: View {
    @Environment(\.dismiss) private var dismiss

    let content: UnavailableCapabilityContent
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if onDismiss != nil {
                sheetHeader
                Divider()
            }
            ScrollView {
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
            }
        }
        .langoPageBackground()
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            localizedText(presentationTitleKey)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: dismissSheet) {
                localizedText("common.close")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var presentationTitleKey: String {
        content.titleKey
    }

    private func dismissSheet() {
        onDismiss?()
        dismiss()
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
