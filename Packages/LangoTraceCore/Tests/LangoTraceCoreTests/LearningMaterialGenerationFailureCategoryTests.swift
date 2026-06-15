import Foundation
import LangoTraceCore
import Testing

/// Pins the failure-category vocabulary that the AI text services translate
/// provider HTTP failures into (系列 E0a Phase 2). The AI package owns the
/// status-code → category mapping; this Core suite guards that the precise
/// cases those mappers depend on keep existing and stay distinct, so a rename
/// or accidental removal is caught at the contract layer rather than silently
/// collapsing into a coarse category.
@Suite("Learning material generation failure category vocabulary")
struct LearningMaterialGenerationFailureCategoryTests {
    @Test("rate-limited case exists and is distinct from generic provider rejection")
    func rateLimitedCaseExists() {
        #expect(LearningMaterialGenerationFailureCategory.rateLimited != .providerRejected)
    }

    @Test("authentication-failure case exists and is distinct from missing credential")
    func authenticationFailedCaseExists() {
        #expect(LearningMaterialGenerationFailureCategory.authenticationFailed != .credentialMissing)
        #expect(LearningMaterialGenerationFailureCategory.authenticationFailed != .providerRejected)
    }

    @Test("precise provider categories stay mutually distinct")
    func preciseProviderCategoriesAreDistinct() {
        let categories: [LearningMaterialGenerationFailureCategory] = [
            .authenticationFailed,
            .rateLimited,
            .unsupportedModel,
            .providerRejected,
        ]
        #expect(Set(categories.map { "\($0)" }).count == categories.count)
    }
}
