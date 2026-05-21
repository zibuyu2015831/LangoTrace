import Foundation
@testable import LangoTraceCore
import Testing

@Test("Language space input normalizes display names without over folding")
func languageSpaceInputNormalizesDisplayNamesWithoutOverFolding() throws {
    let input = CreateLanguageSpaceInput(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b2,
        displayName: "  Cafe\u{301}   SPACE  "
    )

    let normalized = try input.normalized()

    #expect(normalized.displayName == "Cafe\u{301}   SPACE")
    #expect(normalized.displayNameNormalized == "café space")
}

@Test("Language space normalization keeps CJK and fullwidth distinctions")
func languageSpaceNormalizationKeepsCJKAndFullwidthDistinctions() throws {
    let simplified = try CreateLanguageSpaceInput(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "ja",
        level: .a2,
        displayName: " 汉语 "
    ).normalized()
    let traditional = try CreateLanguageSpaceInput(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "ja",
        level: .a2,
        displayName: " 漢語 "
    ).normalized()
    let fullwidth = try CreateLanguageSpaceInput(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "ja",
        level: .a2,
        displayName: " ＡＢＣ "
    ).normalized()

    #expect(simplified.displayNameNormalized == "汉语")
    #expect(traditional.displayNameNormalized == "漢語")
    #expect(fullwidth.displayNameNormalized == "ＡＢＣ")
}

@Test("Onboarding draft creates a language space input instead of a persisted identity")
func onboardingDraftCreatesLanguageSpaceInput() throws {
    let draft = OnboardingDraft(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1
    )

    let input = try draft.makeLanguageSpaceInput()

    #expect(input.nativeLanguageCode == "zh-Hans")
    #expect(input.targetLanguageCode == "en")
    #expect(input.level == .b1)
    #expect(input.displayName == "英语空间")
}

@Test("Language space maps to preview without using language code as identity")
func languageSpaceMapsToPreviewWithoutLanguageCodeIdentity() {
    let space = LanguageSpace(
        id: "space-1",
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .c1,
        displayName: "Work English",
        displayNameNormalized: "work english",
        createdAt: Date(timeIntervalSince1970: 10),
        updatedAt: Date(timeIntervalSince1970: 20),
        lastOpenedAt: Date(timeIntervalSince1970: 30),
        deletedAt: nil
    )

    let preview = space.preview

    #expect(preview.id == "space-1")
    #expect(preview.name == "Work English")
    #expect(preview.nativeLanguage == "中文")
    #expect(preview.targetLanguage == "英语")
    #expect(preview.targetLanguageCode == "en")
    #expect(preview.level == .c1)
}

@Test("Deleted language spaces do not map to active preview")
func deletedLanguageSpacesDoNotMapToActivePreview() {
    let space = LanguageSpace(
        id: "space-1",
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        displayName: "英语空间",
        displayNameNormalized: "英语空间",
        createdAt: Date(timeIntervalSince1970: 10),
        updatedAt: Date(timeIntervalSince1970: 20),
        lastOpenedAt: nil,
        deletedAt: Date(timeIntervalSince1970: 30)
    )

    #expect(space.activePreview == nil)
}
