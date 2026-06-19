import SwiftUI

struct PadOnboardingValueItem: Identifiable {
    let id: String
    let systemImage: String
    let titleKey: String
    let subtitleKey: String
}

struct PadOnboardingValueStripItem: View {
    let item: PadOnboardingValueItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            valueIcon(systemImage: item.systemImage)

            VStack(alignment: .leading, spacing: 4) {
                LocalizedText(item.titleKey)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
                LocalizedText(item.subtitleKey)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PadOnboardingValueListItem: View {
    let item: PadOnboardingValueItem

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            valueIcon(systemImage: item.systemImage)
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                LocalizedText(item.titleKey)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
                LocalizedText(item.subtitleKey)
                    .font(.subheadline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private func valueIcon(systemImage: String) -> some View {
    Image(systemName: systemImage)
        .font(.headline)
        .foregroundStyle(LangoTraceDesign.ColorToken.teal)
        .frame(width: 44, height: 44)
        .background(LangoTraceDesign.ColorToken.paleTeal)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
}
