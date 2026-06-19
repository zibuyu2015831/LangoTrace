@testable import LangoTraceCore
import Testing

@Suite("Reading appearance profile")
struct ReadingAppearanceProfileTests {
    @Test("default profile exposes required reading roles")
    func defaultProfileExposesRequiredRoles() {
        let profile = ReadingAppearanceProfile.default

        #expect(profile.typographyRoles.contains(.body))
        #expect(profile.typographyRoles.contains(.heading(level: 1)))
        #expect(profile.typographyRoles.contains(.blockquote))
        #expect(profile.typographyRoles.contains(.listItem))
        #expect(profile.typographyRoles.contains(.codeBlock))
        #expect(profile.inlineRoles.contains(.link))
        #expect(profile.inlineRoles.contains(.inlineCode))
        #expect(profile.readingWidth.points > 0)
        #expect(profile.lineSpacing > 0)
        #expect(profile.paragraphSpacing > 0)
        #expect(profile.colorRoles.contains(.darkModeBackground))
        #expect(profile.dynamicTypeStrategy == .scaleWithSystem)
    }

    @Test("appearance profile is excluded from document identity")
    func profileIsExcludedFromDocumentIdentity() {
        let identity = ReadingDocumentIdentity(
            bodyHash: "hash",
            contentRevision: 2,
            structureVersion: 7,
            sourceAnchorID: "anchor-1",
            ttsSourceKey: "readingDocumentSentence|doc|sentence"
        )

        #expect(identity.withAppearance(.default) == identity)
    }

    @Test("future custom styles are represented by profile values")
    func futureCustomStylesAreProfileValues() {
        var profile = ReadingAppearanceProfile.default
        profile.lineSpacing = 7
        profile.paragraphSpacing = 18
        profile.readingWidth = .points(680)

        #expect(profile.lineSpacing == 7)
        #expect(profile.paragraphSpacing == 18)
        #expect(profile.readingWidth.points == 680)
    }
}
