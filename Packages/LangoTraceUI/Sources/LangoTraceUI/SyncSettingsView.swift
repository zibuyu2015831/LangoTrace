import LangoTraceCore
import SwiftUI

struct SyncSettingsView: View {
    let languageSpace: LanguageSpacePreview
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var draft = SyncSettingsDraft()
    @State private var showsICloudPreview = false
    @State private var showsS3Draft = false

    var body: some View {
        // Establish a dependency on the interface locale so this container's
        // inline `localizedText` copy re-renders on language change; value-stable
        // leaf subviews resolve reactively via `LocalizedText`.
        let _ = locale
        syncSettingsContent
            .sheet(isPresented: $showsICloudPreview) {
                NavigationStack {
                    ICloudSyncPreviewView()
                }
            }
            .sheet(isPresented: $showsS3Draft) {
                NavigationStack {
                    S3SyncDraftView()
                }
            }
    }

    @ViewBuilder
    private var syncSettingsContent: some View {
        if horizontalSizeClass == .compact {
            stackedContent
        } else {
            ViewThatFits(in: .horizontal) {
                regularColumnsContent
                stackedContent
            }
        }
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            syncStatusCard
            methodCards
            scopeCard
            mockBoundaryCard
            futureOptionsCard
        }
    }

    private var regularColumnsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            syncStatusCard
            methodCardsGrid
            HStack(alignment: .top, spacing: 18) {
                scopeCard
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 18) {
                    mockBoundaryCard
                    futureOptionsCard
                }
                .frame(maxWidth: 340, alignment: .topLeading)
            }
        }
        .frame(minWidth: 760, alignment: .leading)
    }

    private var syncStatusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .frame(width: 42, height: 42)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    localizedText("syncSettings.status.title")
                        .font(.headline)
                    InlineStatusLabel(localizedTextKey: draft.status.titleKey, systemImage: "lock")
                }
                localizedText("syncSettings.status.summary")
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(languageSpace.displayContext)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
    }

    private var methodCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            AIProviderSectionTitle("syncSettings.methods.title")
            ForEach(draft.methods) { method in
                SyncMethodCard(option: method) {
                    switch method.kind {
                    case .iCloud:
                        showsICloudPreview = true
                    case .s3Compatible:
                        showsS3Draft = true
                    }
                }
            }
        }
    }

    private var methodCardsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            AIProviderSectionTitle("syncSettings.methods.title")
            HStack(alignment: .top, spacing: 14) {
                ForEach(draft.methods) { method in
                    SyncMethodCard(option: method) {
                        switch method.kind {
                        case .iCloud:
                            showsICloudPreview = true
                        case .s3Compatible:
                            showsS3Draft = true
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            AIProviderSectionTitle("syncSettings.scope.title")
            ForEach(draft.scopeItems) { item in
                SyncScopeRow(
                    item: item,
                    isIncluded: bindingForScope(item.kind)
                )
            }
        }
        .langoPanel()
    }

    private func bindingForScope(_ kind: SyncScopeKind) -> Binding<Bool> {
        Binding {
            draft.scopeItems.first(where: { $0.kind == kind })?.state == .included
        } set: { newValue in
            draft.setScopeInclusion(kind, isIncluded: newValue)
        }
    }

    private var mockBoundaryCard: some View {
        LocalizedCompactPanel(
            titleKey: "syncSettings.mockBoundary.title",
            textKey: "syncSettings.mockBoundary.body",
            systemImage: "exclamationmark.shield"
        )
    }

    private var futureOptionsCard: some View {
        LocalizedTextPanel(
            titleKey: "syncSettings.future.title",
            textKey: "syncSettings.future.body"
        )
    }
}

private struct SyncMethodCard: View {
    let option: SyncMethodOption
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: option.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                    .frame(width: 38, height: 38)
                    .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        localizedText(option.titleKey)
                            .font(.headline)
                        InlineStatusLabel(localizedTextKey: option.badge.titleKey, systemImage: badgeImageName)
                    }
                    localizedText(option.summaryKey)
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Button(action: action) {
                localizedText(option.actionKey)
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.bordered)
            .tint(LangoTraceDesign.ColorToken.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
    }

    private var badgeImageName: String {
        switch option.badge {
        case .recommended:
            "checkmark.seal"
        case .advanced:
            "slider.horizontal.3"
        }
    }
}

private struct SyncScopeRow: View {
    let item: SyncScopeItem
    let isIncluded: Binding<Bool>

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.kind.systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                LocalizedText(item.titleKey)
                    .font(.callout.weight(.semibold))
                LocalizedText(item.summaryKey)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if item.kind.isUserToggleableDraft {
                Toggle(isOn: isIncluded) {
                    localizedText(item.state.titleKey)
                }
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(LangoTraceDesign.ColorToken.switchOnFill)
                .accessibilityLabel(localizedString(item.titleKey))
                .accessibilityValue(localizedString(item.state.titleKey))
            } else {
                LocalizedText(item.state.titleKey)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(LangoTraceDesign.ColorToken.surfaceMuted)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget, alignment: .leading)
    }

    private var iconColor: Color {
        switch item.state {
        case .included:
            LangoTraceDesign.ColorToken.accent
        case .offByDefault:
            LangoTraceDesign.ColorToken.textSecondary
        case .localRebuild:
            LangoTraceDesign.ColorToken.warning
        case .localKeychainOnly:
            LangoTraceDesign.ColorToken.accentStrong
        }
    }
}

private struct ICloudSyncPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LocalizedCompactPanel(
                    titleKey: "syncSettings.iCloudPreview.title",
                    textKey: "syncSettings.iCloudPreview.body",
                    systemImage: "icloud"
                )
                LocalizedTextPanel(
                    titleKey: "syncSettings.iCloudPreview.boundary.title",
                    textKey: "syncSettings.iCloudPreview.boundary.body"
                )
                LocalizedTextPanel(
                    titleKey: "syncSettings.iCloudPreview.checklist.title",
                    textKey: "syncSettings.iCloudPreview.checklist.body"
                )
                Button {
                    dismiss()
                } label: {
                    LocalizedText("syncSettings.iCloudPreview.close")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                        .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(LangoTraceDesign.ColorToken.primaryActionFill)
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(localizedString("syncSettings.iCloudPreview.navigationTitle"))
        .langoInlineModalTitle()
        .langoPageBackground()
    }
}

private extension View {
    @ViewBuilder
    func langoInlineModalTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
