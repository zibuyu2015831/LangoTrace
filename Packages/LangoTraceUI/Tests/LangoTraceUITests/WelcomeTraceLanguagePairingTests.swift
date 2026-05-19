import Foundation
import Testing

@Suite("Welcome trace language pairing")
struct WelcomeTraceLanguagePairingTests {
    @Test("Welcome examples switch learning target from interface language")
    func welcomeExamplesSwitchLearningTargetFromInterfaceLanguage() throws {
        let catalog = try WelcomePairingStringCatalog.load(from: stringCatalogURL)

        for expectation in welcomeLanguagePairingExpectations {
            try assertExample(expectation, in: catalog)
        }
    }

    private var stringCatalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent("Resources/Localizable.xcstrings")
    }

    private func assertExample(
        _ expectation: WelcomeLanguagePairingExpectation,
        in catalog: WelcomePairingStringCatalog
    ) throws {
        #expect(
            try localizedValue(expectation.sourceNoteKey, expectation.locale, in: catalog) == expectation.source
        )
        #expect(
            try localizedValue(expectation.rewrittenTextKey, expectation.locale, in: catalog) == expectation.rewrite
        )
        #expect(
            try localizedValue(expectation.audioCueKey, expectation.locale, in: catalog)
                .localizedCaseInsensitiveContains(expectation.audioFragment)
        )
        #expect(
            try localizedValue(expectation.shadowingCueKey, expectation.locale, in: catalog)
                .localizedCaseInsensitiveContains(expectation.shadowingFragment)
        )
    }

    private func localizedValue(
        _ key: String,
        _ locale: String,
        in catalog: WelcomePairingStringCatalog
    ) throws -> String {
        let entry = try #require(catalog.strings[key], "Missing catalog key \(key)")
        return try #require(entry.localizedValues[locale], "Missing \(locale) localization for \(key)")
    }
}

private struct WelcomeLanguagePairingExpectation {
    let id: String
    let locale: String
    let source: String
    let rewrite: String
    let audioFragment: String
    let shadowingFragment: String

    var sourceNoteKey: String {
        "welcome.tracePreview.examples.\(id).sourceNote"
    }

    var rewrittenTextKey: String {
        "welcome.tracePreview.examples.\(id).rewrittenText"
    }

    var audioCueKey: String {
        "welcome.tracePreview.examples.\(id).audioCue"
    }

    var shadowingCueKey: String {
        "welcome.tracePreview.examples.\(id).shadowingCue"
    }
}

private let welcomeLanguagePairingExpectations: [WelcomeLanguagePairingExpectation] =
    chineseInterfaceExpectations + nonChineseInterfaceExpectations

private let chineseInterfaceExpectations = [
    WelcomeLanguagePairingExpectation(
        id: "cafe",
        locale: "zh-Hans",
        source: "我拍下咖啡，想学会礼貌地说外带。",
        rewrite: "Could I get this coffee to go, please?",
        audioFragment: "慢速配音",
        shadowingFragment: "tea / sandwich"
    ),
    WelcomeLanguagePairingExpectation(
        id: "commute",
        locale: "zh-Hans",
        source: "地铁晚点了，我记下站台提示，想问是不是要换站台。",
        rewrite: "The train is delayed, so I should check whether I need to change platforms.",
        audioFragment: "delayed",
        shadowingFragment: "train / platform"
    ),
    WelcomeLanguagePairingExpectation(
        id: "meeting",
        locale: "zh-Hans",
        source: "今天开会时，我想确认截止时间，也想问下一步由谁负责。",
        rewrite: "In today’s meeting, I wanted to confirm the deadline and clarify who would own the next step.",
        audioFragment: "confirm / clarify / own",
        shadowingFragment: "deadline / next step"
    ),
]

private let nonChineseInterfaceExpectations = [
    expectation("en", "cafe", englishCafeSource, chineseCafeRewrite, ("Chinese voiceover", "茶 / 三明治")),
    expectation("en", "commute", englishCommuteSource, chineseCommuteRewrite, ("Chinese voiceover", "地铁 / 站台")),
    expectation("en", "meeting", englishMeetingSource, chineseMeetingRewrite, ("Chinese voiceover", "截止时间 / 下一步")),
    expectation("es", "cafe", spanishCafeSource, chineseCafeRewrite, ("voz en chino", "茶 / 三明治")),
    expectation("es", "commute", spanishCommuteSource, chineseCommuteRewrite, ("voz en chino", "地铁 / 站台")),
    expectation("es", "meeting", spanishMeetingSource, chineseMeetingRewrite, ("voz en chino", "截止时间 / 下一步")),
    expectation("ja", "cafe", japaneseCafeSource, chineseCafeRewrite, ("中国語音声", "茶 / 三明治")),
    expectation("ja", "commute", japaneseCommuteSource, chineseCommuteRewrite, ("中国語音声", "地铁 / 站台")),
    expectation("ja", "meeting", japaneseMeetingSource, chineseMeetingRewrite, ("中国語音声", "截止时间 / 下一步")),
    expectation("fr", "cafe", frenchCafeSource, chineseCafeRewrite, ("Voix chinoise", "茶 / 三明治")),
    expectation("fr", "commute", frenchCommuteSource, chineseCommuteRewrite, ("Voix chinoise", "地铁 / 站台")),
    expectation("fr", "meeting", frenchMeetingSource, chineseMeetingRewrite, ("Voix chinoise", "截止时间 / 下一步")),
    expectation("de", "cafe", germanCafeSource, chineseCafeRewrite, ("Chinesische Stimme", "Tee / Sandwich")),
    expectation("de", "commute", germanCommuteSource, chineseCommuteRewrite, ("Chinesische Stimme", "地铁 / 站台")),
    expectation("de", "meeting", germanMeetingSource, chineseMeetingRewrite, ("Chinesische Stimme", "截止时间 / 下一步")),
    expectation("ko", "cafe", koreanCafeSource, chineseCafeRewrite, ("중국어 음성", "茶 / 三明治")),
    expectation("ko", "commute", koreanCommuteSource, chineseCommuteRewrite, ("중국어 음성", "地铁 / 站台")),
    expectation("ko", "meeting", koreanMeetingSource, chineseMeetingRewrite, ("중국어 음성", "截止时间 / 下一步")),
    expectation("ru", "cafe", russianCafeSource, chineseCafeRewrite, ("Китайская озвучка", "茶 / 三明治")),
    expectation("ru", "commute", russianCommuteSource, chineseCommuteRewrite, ("Китайская озвучка", "地铁 / 站台")),
    expectation("ru", "meeting", russianMeetingSource, chineseMeetingRewrite, ("Китайская озвучка", "截止时间 / 下一步")),
]

private func expectation(
    _ locale: String,
    _ id: String,
    _ source: String,
    _ rewrite: String,
    _ cues: (audio: String, shadowing: String)
) -> WelcomeLanguagePairingExpectation {
    WelcomeLanguagePairingExpectation(
        id: id,
        locale: locale,
        source: source,
        rewrite: rewrite,
        audioFragment: cues.audio,
        shadowingFragment: cues.shadowing
    )
}

private let chineseCafeRewrite = "这杯咖啡可以帮我打包吗？"
private let chineseCommuteRewrite = "地铁晚点了，我需要确认一下要不要换站台。"
private let chineseMeetingRewrite = "今天会议上，我想确认截止时间，并明确下一步由谁负责。"

private let englishCafeSource = "I took a photo of my coffee and wanted to learn a polite takeaway phrase."
private let englishCommuteSource =
    "The subway was delayed, so I noted the platform sign and wanted to ask if I should switch platforms."
private let englishMeetingSource =
    "In today’s meeting, I wanted to confirm the deadline and ask who owns the next step."
private let spanishCafeSource = "Hice una foto de mi cafe y queria aprender a pedirlo para llevar con cortesia."
private let spanishCommuteSource =
    "El metro se retraso, anote el aviso del anden y queria preguntar si debia cambiar de anden."
private let spanishMeetingSource =
    "En la reunion de hoy queria confirmar la fecha limite y preguntar quien se encarga del siguiente paso."
private let japaneseCafeSource = "コーヒーの写真を撮り、丁寧にテイクアウトを頼む言い方を覚えたい。"
private let japaneseCommuteSource = "地下鉄が遅れたので、ホームの案内をメモし、乗り場を変えるべきか聞きたい。"
private let japaneseMeetingSource = "今日の会議で締め切りを確認し、次のステップを誰が担当するか聞きたい。"
private let frenchCafeSource =
    "J ai pris une photo de mon cafe et je voulais apprendre une formule polie pour l emporter."
private let frenchCommuteSource =
    "Le metro avait du retard, j ai note l annonce du quai et je voulais demander s il fallait changer de quai."
private let frenchMeetingSource =
    "Dans la reunion d aujourd hui, je voulais confirmer l echeance et demander qui prendrait la suite."
private let germanCafeSource =
    "Ich habe meinen Kaffee fotografiert und wollte lernen, wie man hoeflich zum Mitnehmen sagt."
private let germanCommuteSource =
    "Die U-Bahn hatte Verspaetung, ich notierte den Hinweis am Bahnsteig und wollte fragen, ob ich " +
    "den Bahnsteig wechseln muss."
private let germanMeetingSource =
    "Im heutigen Meeting wollte ich die Frist bestaetigen und fragen, wer den naechsten Schritt uebernimmt."
private let koreanCafeSource = "커피 사진을 찍고 정중하게 포장해 달라고 말하는 법을 배우고 싶었다."
private let koreanCommuteSource = "지하철이 지연되어 승강장 안내를 적어 두고 승강장을 바꿔야 하는지 묻고 싶었다."
private let koreanMeetingSource = "오늘 회의에서 마감일을 확인하고 다음 단계를 누가 맡는지 묻고 싶었다."
private let russianCafeSource = "Я сфотографировал кофе и хотел выучить вежливую фразу для заказа с собой."
private let russianCommuteSource =
    "Метро задерживалось, я записал объявление на платформе и хотел спросить, нужно ли перейти на другую платформу."
private let russianMeetingSource =
    "На сегодняшней встрече я хотел уточнить срок и спросить, кто отвечает за следующий шаг."

private struct WelcomePairingStringCatalog: Decodable {
    let strings: [String: WelcomePairingStringCatalogEntry]

    static func load(from url: URL) throws -> WelcomePairingStringCatalog {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WelcomePairingStringCatalog.self, from: data)
    }
}

private struct WelcomePairingStringCatalogEntry: Decodable {
    let localizations: [String: WelcomePairingLocalization]

    var localizedValues: [String: String] {
        localizations.mapValues(\.stringUnit.value)
    }
}

private struct WelcomePairingLocalization: Decodable {
    let stringUnit: WelcomePairingStringUnit
}

private struct WelcomePairingStringUnit: Decodable {
    let value: String
}
