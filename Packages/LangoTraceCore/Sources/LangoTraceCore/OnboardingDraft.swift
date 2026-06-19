public struct OnboardingDraft: Equatable, Sendable {
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var level: LanguageLevel

    public init(
        nativeLanguageCode: String = LearningLanguage.defaultNative.code,
        targetLanguageCode: String = LearningLanguage.defaultTarget.code,
        level: LanguageLevel = .b1
    ) {
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.level = level
    }

    public var resolvedNativeLanguage: LearningLanguage {
        LearningLanguage.find(code: nativeLanguageCode) ?? LearningLanguage.defaultNative
    }

    public var resolvedTargetLanguage: LearningLanguage {
        LearningLanguage.find(code: targetLanguageCode) ?? LearningLanguage.defaultTarget
    }

    public var availableTargetLanguages: [LearningLanguage] {
        LearningLanguage.targetLanguages(excludingNativeCode: resolvedNativeLanguage.code)
    }

    public func normalized() -> OnboardingDraft {
        guard LearningLanguage.find(code: nativeLanguageCode) != nil,
              LearningLanguage.find(code: targetLanguageCode) != nil
        else {
            return OnboardingDraft(level: level)
        }

        guard nativeLanguageCode != targetLanguageCode else {
            return OnboardingDraft(
                nativeLanguageCode: nativeLanguageCode,
                targetLanguageCode: availableTargetLanguages.first?.code ?? LearningLanguage.defaultTarget.code,
                level: level
            )
        }

        return self
    }

    public func makeLanguageSpacePreview() -> LanguageSpacePreview {
        let normalizedDraft = normalized()
        let nativeLanguage = normalizedDraft.resolvedNativeLanguage
        let targetLanguage = normalizedDraft.resolvedTargetLanguage

        return LanguageSpacePreview(
            id: targetLanguage.code,
            name: targetLanguage.defaultSpaceName,
            nativeLanguage: nativeLanguage.zhHansName,
            targetLanguage: targetLanguage.zhHansName,
            level: normalizedDraft.level
        )
    }

    public func makeLanguageSpaceInput() throws -> CreateLanguageSpaceInput {
        let normalizedDraft = normalized()
        return CreateLanguageSpaceInput(
            nativeLanguageCode: normalizedDraft.nativeLanguageCode,
            targetLanguageCode: normalizedDraft.targetLanguageCode,
            level: normalizedDraft.level,
            displayName: normalizedDraft.resolvedTargetLanguage.defaultSpaceName
        )
    }
}
