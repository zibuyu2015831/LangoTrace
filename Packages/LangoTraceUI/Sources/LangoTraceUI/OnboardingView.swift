import LangoTraceCore
import SwiftUI

struct OnboardingView: View {
    @Binding var draft: OnboardingDraft
    let onCreateLanguageSpace: () -> Void

    private let onboardingContentMaxWidth: CGFloat = 680
    private let onboardingBottomActionMaxWidth: CGFloat = 520
    private let levelSelectorApproxVisibleRows: CGFloat = 3
    private let padLevelSelectorApproxVisibleRows: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var compactLevelRowMinHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var compactLevelRowSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            if usesPadLandscapeOnboardingLayout(in: size) {
                padLandscapeOnboardingContent(size: size)
            } else if usesPadPortraitOnboardingLayout(in: size) {
                padPortraitOnboardingContent(size: size)
            } else if usesInlineWideOnboardingLayout(in: size) {
                wideOnboardingContent(size: size)
            } else {
                compactOnboardingContentWithBottomAction
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .langoPageBackground()
    }

    private func usesPadLandscapeOnboardingLayout(in size: CGSize) -> Bool {
        #if os(iOS)
            size.width >= 980 && size.height >= 680 && size.width > size.height
        #else
            false
        #endif
    }

    private func usesPadPortraitOnboardingLayout(in size: CGSize) -> Bool {
        #if os(iOS)
            size.width >= 760 && size.height >= 900 && size.height > size.width
        #else
            false
        #endif
    }

    private func usesInlineWideOnboardingLayout(in size: CGSize) -> Bool {
        #if os(iOS)
            size.width >= 760 && size.height >= 720
        #else
            size.width >= 760 && size.height >= 620
        #endif
    }
}

private extension OnboardingView {
    private var compactOnboardingContentWithBottomAction: some View {
        ZStack {
            ScrollView {
                onboardingFormContent
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 148)
                    .frame(maxWidth: onboardingContentMaxWidth, alignment: .leading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            createButton
        }
    }

    private func wideOnboardingContent(size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                onboardingFormContent
                inlineCreateButton
            }
            .padding(.horizontal, 24)
            .padding(.top, onboardingWideTopPadding(in: size))
            .padding(.bottom, 64)
            .frame(maxWidth: onboardingContentMaxWidth, minHeight: size.height, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private func padPortraitOnboardingContent(size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                padPortraitValueStrip
                languageForm(levelVisibleRows: padLevelSelectorApproxVisibleRows)
                inlineCreateButton
            }
            .padding(.horizontal, 28)
            .padding(.top, padPortraitTopPadding(in: size))
            .padding(.bottom, 58)
            .frame(maxWidth: 700, minHeight: size.height, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private func padLandscapeOnboardingContent(size: CGSize) -> some View {
        ScrollView {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 42) {
                    header
                    padOnboardingValueList
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 430, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, padLandscapeHorizontalPadding(in: size))
                .padding(.trailing, 52)
                .padding(.top, padLandscapeTopPadding(in: size))
                .padding(.bottom, 76)
                .frame(width: size.width * 0.4, alignment: .topLeading)

                Rectangle()
                    .fill(LangoTraceDesign.ColorToken.hairline.opacity(0.45))
                    .frame(width: 1)
                    .padding(.vertical, 48)
                    .accessibilityHidden(true)

                VStack(alignment: .center, spacing: 26) {
                    languageForm(levelVisibleRows: padLevelSelectorApproxVisibleRows)
                        .frame(maxWidth: 700)
                    inlineCreateButton
                }
                .padding(.horizontal, 48)
                .padding(.top, padLandscapeTopPadding(in: size))
                .padding(.bottom, 54)
                .frame(width: size.width * 0.6, alignment: .top)
                .frame(minHeight: size.height, alignment: .top)
            }
            .frame(minHeight: size.height, alignment: .top)
        }
        .scrollIndicators(.hidden)
    }

    private var onboardingFormContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            header
            languageForm
        }
    }

    private func onboardingWideTopPadding(in size: CGSize) -> CGFloat {
        if size.height >= 1180 {
            78
        } else if size.height >= 900 {
            64
        } else {
            44
        }
    }

    private func padPortraitTopPadding(in size: CGSize) -> CGFloat {
        if size.height >= 1180 {
            118
        } else if size.height >= 1020 {
            88
        } else {
            72
        }
    }

    private func padLandscapeTopPadding(in size: CGSize) -> CGFloat {
        if size.height >= 900 {
            104
        } else {
            72
        }
    }

    private func padLandscapeHorizontalPadding(in size: CGSize) -> CGFloat {
        size.width >= 1260 ? 96 : 80
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(LangoTraceDesign.ColorToken.gold)
                    .frame(width: 8, height: 8)
                localizedText("onboarding.eyebrow")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            localizedText("onboarding.title")
                .font(.system(.largeTitle, design: .default, weight: .semibold))
            localizedText("onboarding.subtitle")
                .font(.body.weight(.regular))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageForm: some View {
        languageForm(levelVisibleRows: levelSelectorApproxVisibleRows)
    }

    private func languageForm(levelVisibleRows: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PickerRow(
                titleKey: "onboarding.nativeLanguage",
                systemImage: "person.text.rectangle"
            ) {
                LanguageMenu(
                    titleKey: "onboarding.nativeLanguage",
                    selectedLanguage: draft.resolvedNativeLanguage,
                    languages: LearningLanguage.supportedNativeLanguages,
                    onSelect: { language in
                        draft.nativeLanguageCode = language.code
                        draft = draft.normalized()
                    }
                )
            }

            Divider()

            PickerRow(
                titleKey: "onboarding.targetLanguage",
                systemImage: "text.bubble"
            ) {
                LanguageMenu(
                    titleKey: "onboarding.targetLanguage",
                    selectedLanguage: draft.resolvedTargetLanguage,
                    languages: draft.availableTargetLanguages,
                    onSelect: { language in
                        draft.targetLanguageCode = language.code
                        draft = draft.normalized()
                    }
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                        .frame(width: 30, height: 30)
                        .background(LangoTraceDesign.ColorToken.paleTeal)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        localizedText("onboarding.level.title")
                            .font(.headline)
                        localizedText("onboarding.level.summary")
                            .font(.footnote)
                            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                compactLevelSelector(visibleRows: levelVisibleRows)
            }
        }
        .langoPanel(padding: 18)
        .langoSoftShadow()
    }

    private var padOnboardingValueItems: [PadOnboardingValueItem] {
        [
            PadOnboardingValueItem(
                id: "record",
                systemImage: "camera",
                titleKey: "onboarding.value.record.title",
                subtitleKey: "onboarding.value.record.subtitle"
            ),
            PadOnboardingValueItem(
                id: "practice",
                systemImage: "book",
                titleKey: "onboarding.value.practice.title",
                subtitleKey: "onboarding.value.practice.subtitle"
            ),
            PadOnboardingValueItem(
                id: "trace",
                systemImage: "leaf",
                titleKey: "onboarding.value.trace.title",
                subtitleKey: "onboarding.value.trace.subtitle"
            ),
        ]
    }

    private var padPortraitValueStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 26) {
                ForEach(padOnboardingValueItems) { item in
                    PadOnboardingValueStripItem(item: item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(padOnboardingValueItems) { item in
                    PadOnboardingValueListItem(item: item)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var padOnboardingValueList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(padOnboardingValueItems.enumerated()), id: \.element.id) { index, item in
                PadOnboardingValueListItem(item: item)

                if index < padOnboardingValueItems.count - 1 {
                    Divider()
                        .padding(.vertical, 24)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var compactLevelSelector: some View {
        compactLevelSelector(visibleRows: levelSelectorApproxVisibleRows)
    }

    private func compactLevelSelector(visibleRows: CGFloat) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: compactLevelRowSpacing) {
                ForEach(LanguageLevel.allCases, id: \.self) { level in
                    compactLevelRow(for: level)
                }
            }
        }
        .frame(maxHeight: levelSelectorMaxHeight(visibleRows: visibleRows))
        .scrollIndicators(.visible)
        .accessibilityLabel(localizedText("onboarding.level.title"))
        .accessibilityHint(
            localizedString("onboarding.level.accessibilityHint", draft.resolvedTargetLanguage.nativeName)
        )
    }

    private var compactLevelSelectorMaxHeight: CGFloat {
        levelSelectorMaxHeight(visibleRows: levelSelectorApproxVisibleRows)
    }

    private func levelSelectorMaxHeight(visibleRows: CGFloat) -> CGFloat {
        compactLevelRowMinHeight * visibleRows +
            compactLevelRowSpacing * (visibleRows - 1)
    }

    private func compactLevelRow(for level: LanguageLevel) -> some View {
        let selected = draft.level == level

        return Button {
            draft.level = level
        } label: {
            HStack(spacing: 10) {
                Text(level.rawValue)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                    .frame(width: 38, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    localizedText(onboardingLevelTitleKey(for: level))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    localizedText(onboardingLevelDescriptionKey(for: level))
                        .font(.caption)
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(selected ? LangoTraceDesign.ColorToken.teal : LangoTraceDesign.ColorToken.hairline)
            }
            .frame(minHeight: max(compactLevelRowMinHeight, LangoTraceDesign.Density.minimumTouchTarget))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? LangoTraceDesign.ColorToken.paleTeal : LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        selected
                            ? LangoTraceDesign.ColorToken.teal.opacity(0.55)
                            : LangoTraceDesign.ColorToken.hairline,
                        lineWidth: selected ? 1.2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(level.rawValue), \(localizedString(onboardingLevelTitleKey(for: level)))"))
        .accessibilityValue(localizedText(onboardingLevelDescriptionKey(for: level)))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func onboardingLevelTitleKey(for level: LanguageLevel) -> String {
        switch level {
        case .a1:
            "onboarding.level.a1.title"
        case .a2:
            "onboarding.level.a2.title"
        case .b1:
            "onboarding.level.b1.title"
        case .b2:
            "onboarding.level.b2.title"
        case .c1:
            "onboarding.level.c1.title"
        case .c2:
            "onboarding.level.c2.title"
        }
    }

    private func onboardingLevelDescriptionKey(for level: LanguageLevel) -> String {
        switch level {
        case .a1:
            "onboarding.level.a1.description"
        case .a2:
            "onboarding.level.a2.description"
        case .b1:
            "onboarding.level.b1.description"
        case .b2:
            "onboarding.level.b2.description"
        case .c1:
            "onboarding.level.c1.description"
        case .c2:
            "onboarding.level.c2.description"
        }
    }

    private var createButtonContent: some View {
        VStack(spacing: 8) {
            Text(createSummary)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            Button(action: onCreateLanguageSpace) {
                Label {
                    localizedText("onboarding.createSpace")
                } icon: {
                    Image(systemName: "plus.circle.fill")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(LangoTraceDesign.ColorToken.whiteInk)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .tint(LangoTraceDesign.ColorToken.deepTeal)
            .accessibilityHint(
                localizedString("onboarding.createSpace.accessibilityHint", draft.resolvedTargetLanguage.nativeName)
            )
            localStorageFootnote
        }
        .frame(maxWidth: onboardingBottomActionMaxWidth)
    }

    private var localStorageFootnote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "lock")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
            localizedText("onboarding.privacy.footnote")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var createButton: some View {
        createButtonContent
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(.regularMaterial)
    }

    private var inlineCreateButton: some View {
        createButtonContent
            .padding(.top, 18)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var createSummary: String {
        "\(draft.resolvedNativeLanguage.displayTitle(for: .selectedValue)) -> " +
            "\(draft.resolvedTargetLanguage.displayTitle(for: .selectedValue)) · \(draft.level.rawValue)"
    }
}

private struct PadOnboardingValueItem: Identifiable {
    let id: String
    let systemImage: String
    let titleKey: String
    let subtitleKey: String
}

private struct PadOnboardingValueStripItem: View {
    let item: PadOnboardingValueItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            valueIcon(systemImage: item.systemImage)

            VStack(alignment: .leading, spacing: 4) {
                localizedText(item.titleKey)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
                localizedText(item.subtitleKey)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PadOnboardingValueListItem: View {
    let item: PadOnboardingValueItem

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            valueIcon(systemImage: item.systemImage)
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                localizedText(item.titleKey)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
                localizedText(item.subtitleKey)
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

private struct LanguageMenu: View {
    let titleKey: String
    let selectedLanguage: LearningLanguage
    let languages: [LearningLanguage]
    let onSelect: (LearningLanguage) -> Void

    var body: some View {
        Menu {
            ForEach(languages) { language in
                Button {
                    onSelect(language)
                } label: {
                    Text(language.displayTitle(for: .onboardingPicker))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedLanguage.displayTitle(for: .selectedValue))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.headline)
            .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(LangoTraceDesign.ColorToken.hairline.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.button)
        .accessibilityLabel(localizedText(titleKey))
        .accessibilityValue(selectedLanguage.displayTitle(for: .onboardingPicker))
        .accessibilityHint(localizedText(titleKey))
    }
}

private struct PickerRow<PickerContent: View>: View {
    let titleKey: String
    let systemImage: String
    @ViewBuilder let picker: PickerContent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                .frame(width: 30, height: 30)
                .background(LangoTraceDesign.ColorToken.paleTeal)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                localizedText(titleKey)
                    .font(.headline)
            }
            Spacer(minLength: 12)
            picker
                .labelsHidden()
                .pickerStyle(.menu)
        }
        .frame(minHeight: 52)
    }
}
