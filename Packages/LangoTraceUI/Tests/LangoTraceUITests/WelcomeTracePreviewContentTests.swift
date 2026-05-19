import Foundation
import Testing

@Suite("Welcome trace preview content")
struct WelcomeTracePreviewContentTests {
    @Test("Expanded welcome trace card shows the source note only in its section")
    func expandedWelcomeTraceCardShowsSourceNoteOnlyInItsSection() throws {
        let carouselSource = try String(contentsOf: carouselSourceURL, encoding: .utf8)
        let sourceNoteReferences = carouselSource
            .components(separatedBy: "localizedText(example.sourceNoteKey)")
            .count - 1

        #expect(sourceNoteReferences == 2)
        #expect(carouselSource.contains(#"PreviewSection(titleKey: "welcome.tracePreview.sourceNoteTitle")"#))
        #expect(!carouselSource.contains("""
        if isExpanded {
                    localizedText(example.sourceNoteKey)
        """))
    }

    @Test("Welcome subtitle removes audio input from confirmed life-action copy")
    func welcomeSubtitleRemovesAudioInputFromConfirmedLifeActionCopy() throws {
        let catalog = try WelcomePreviewStringCatalog.load(from: stringCatalogURL)
        let subtitleEntry = try #require(catalog.strings["welcome.valueSubtitle"])

        #expect(
            subtitleEntry.localizedValues["zh-Hans"] == "拍照、随笔，\n语迹会帮你整理成表达和练习",
            "Simplified Chinese subtitle must match the confirmed Welcome copy."
        )

        for retiredChinesePhrase in ["写日记", "记录声音", "录音", "单词、表达和练习"] {
            #expect(
                subtitleEntry.localizedValues["zh-Hans"]?.contains(retiredChinesePhrase) == false,
                "Subtitle still contains retired phrase \(retiredChinesePhrase)."
            )
        }

        let retiredAudioInputPhrases = [
            "en": ["record audio"],
            "es": ["graba audio"],
            "ja": ["録音"],
            "fr": ["enregistrez votre voix"],
            "de": ["nimm Audio auf"],
            "ko": ["녹음"],
            "ru": ["записывайте звук"],
        ]

        for (locale, retiredPhrases) in retiredAudioInputPhrases {
            let localizedValue = try #require(subtitleEntry.localizedValues[locale])
            for retiredPhrase in retiredPhrases {
                #expect(
                    localizedValue.localizedCaseInsensitiveContains(retiredPhrase) == false,
                    "\(locale) subtitle still contains audio input phrase \(retiredPhrase)."
                )
            }
        }

        let strings = catalog.strings
        for platformSpecificKey in [
            "welcome.valueSubtitle.iphone",
            "welcome.valueSubtitle.iPad",
            "welcome.valueSubtitle.ipad",
            "welcome.valueSubtitle.mac",
            "welcome.valueSubtitle.macos",
        ] {
            #expect(
                strings[platformSpecificKey] == nil,
                "Welcome subtitle must stay shared instead of using platform-specific key \(platformSpecificKey)."
            )
        }
    }

    @Test("Welcome trace section titles and default meeting example match confirmed copy")
    func welcomeTraceSectionTitlesAndDefaultMeetingExampleMatchConfirmedCopy() throws {
        let catalog = try WelcomePreviewStringCatalog.load(from: stringCatalogURL)
        let requiredLocales = ["en", "zh-Hans", "es", "ja", "fr", "de", "ko", "ru"]

        let meetingRewrite = """
        In today’s meeting, I wanted to confirm the deadline and clarify who would own the next step.
        """
        let expectedChineseValues = [
            "welcome.tracePreview.sourceNoteTitle": "我的随笔",
            "welcome.tracePreview.rewrittenTextTitle": "改写",
            "welcome.tracePreview.audioCueTitle": "配音",
            "welcome.tracePreview.shadowingCueTitle": "跟读",
            "welcome.tracePreview.examples.meeting.level": "高阶 · 会议表达",
            "welcome.tracePreview.examples.meeting.sourceNote": "今天开会时，我想确认截止时间，也想问下一步由谁负责。",
            "welcome.tracePreview.examples.meeting.rewrittenText": meetingRewrite,
            "welcome.tracePreview.examples.meeting.audioCue": "会议语气配音 · 强调 confirm / clarify / own",
            "welcome.tracePreview.examples.meeting.shadowingCue": "按意群跟读 · 替换 deadline / next step 复述",
        ]

        for (key, expectedValue) in expectedChineseValues {
            let entry = try #require(catalog.strings[key], "Missing catalog key \(key)")
            #expect(entry.localizedValues["zh-Hans"] == expectedValue)

            for locale in requiredLocales {
                let value = entry.localizedValues[locale]
                #expect(value?.isEmpty == false, "Missing \(locale) localization for \(key)")
            }
        }
    }

    @Test("Welcome examples show distinct learner levels and useful practice cues")
    func welcomeExamplesShowDistinctLearnerLevelsAndUsefulPracticeCues() throws {
        let catalog = try WelcomePreviewStringCatalog.load(from: stringCatalogURL)
        let expectedChineseValues = [
            "welcome.tracePreview.examples.cafe.level": "入门 · 点单短句",
            "welcome.tracePreview.examples.commute.level": "进阶 · 通勤说明",
            "welcome.tracePreview.examples.meeting.level": "高阶 · 会议表达",
            "welcome.tracePreview.examples.cafe.audioCue": "慢速配音 · 重读 Could I / to go",
            "welcome.tracePreview.examples.cafe.shadowingCue": "先跟读短句 · 换成 tea / sandwich 复用",
            "welcome.tracePreview.examples.commute.audioCue": "清晰配音 · 注意 delayed 和 change platforms",
            "welcome.tracePreview.examples.commute.shadowingCue": "分两段跟读 · 替换 train / platform 复述",
            "welcome.tracePreview.examples.meeting.audioCue": "会议语气配音 · 强调 confirm / clarify / own",
            "welcome.tracePreview.examples.meeting.shadowingCue": "按意群跟读 · 替换 deadline / next step 复述",
        ]

        for (key, expectedValue) in expectedChineseValues {
            let entry = try #require(catalog.strings[key], "Missing catalog key \(key)")
            #expect(entry.localizedValues["zh-Hans"] == expectedValue)
        }

        for key in practiceCueKeys {
            let entry = try #require(catalog.strings[key], "Missing catalog key \(key)")
            for value in entry.localizedValues.values {
                for retiredFragment in retiredCueFragments {
                    #expect(
                        value.localizedCaseInsensitiveContains(retiredFragment) == false,
                        "\(key) still contains low-value cue \(retiredFragment)."
                    )
                }
            }
        }
    }

    private var stringCatalogURL: URL {
        sourceRootURL.appendingPathComponent("Resources/Localizable.xcstrings")
    }

    private var carouselSourceURL: URL {
        sourceRootURL.appendingPathComponent("WelcomeTracePreviewCarousel.swift")
    }

    private var sourceRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
    }

    private var practiceCueKeys: [String] {
        [
            "welcome.tracePreview.examples.cafe.audioCue",
            "welcome.tracePreview.examples.cafe.shadowingCue",
            "welcome.tracePreview.examples.commute.audioCue",
            "welcome.tracePreview.examples.commute.shadowingCue",
            "welcome.tracePreview.examples.meeting.audioCue",
            "welcome.tracePreview.examples.meeting.shadowingCue",
        ]
    }

    private var retiredCueFragments: [String] {
        [
            "自然语速",
            "可慢速播放",
            "收藏这句",
            "Natural pace",
            "Slow playback available",
            "Save this sentence",
        ]
    }
}

private struct WelcomePreviewStringCatalog: Decodable {
    let strings: [String: WelcomePreviewStringCatalogEntry]

    static func load(from url: URL) throws -> WelcomePreviewStringCatalog {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WelcomePreviewStringCatalog.self, from: data)
    }
}

private struct WelcomePreviewStringCatalogEntry: Decodable {
    let localizations: [String: Localization]

    var localizedValues: [String: String] {
        localizations.mapValues(\.stringUnit.value)
    }
}

private struct Localization: Decodable {
    let stringUnit: StringUnit
}

private struct StringUnit: Decodable {
    let value: String
}
