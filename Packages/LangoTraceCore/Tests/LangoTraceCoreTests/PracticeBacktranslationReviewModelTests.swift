import Foundation
import LangoTraceCore
import Testing

/// Pins the E5 Slice 2 back-translation critique model contract: the result is
/// observation/suggestion shaped (never a verdict), the failure vocabulary maps
/// onto the shared log buckets, and the new content descriptors exist for the
/// preview projection.
@Suite("Practice back-translation review models")
struct PracticeBacktranslationReviewModelTests {
    @Test("the critique result carries observations and suggestions, never a verdict/score")
    func resultIsObservationShaped() {
        let result = PracticeBacktranslationReviewResult(
            schemaVersion: "practice_backtranslation_review.v1",
            acknowledgement: "Good effort capturing the core meaning.",
            observations: [
                PracticeBacktranslationReviewObservation(phenomenon: "tense", explanation: "You used past where the reference uses present."),
            ],
            suggestions: ["Try the present tense here."],
            registerNote: nil
        )
        #expect(result.observations.count == 1)
        #expect(result.suggestions == ["Try the present tense here."])
        #expect(result.registerNote == nil)
    }

    @Test("failure categories map onto the standing log buckets")
    func failureMapping() {
        typealias Category = PracticeBacktranslationReviewFailureCategory
        #expect(AIRequestLogFailureBucket(Category.providerNotConfigured) == .providerNotConfigured)
        #expect(AIRequestLogFailureBucket(Category.authenticationFailed) == .credentialMissing)
        #expect(AIRequestLogFailureBucket(Category.networkUnavailable) == .network)
        #expect(AIRequestLogFailureBucket(Category.timeout) == .timeout)
        #expect(AIRequestLogFailureBucket(Category.rateLimited) == .providerRejected)
        #expect(AIRequestLogFailureBucket(Category.unsupportedProvider) == .unsupported)
        #expect(AIRequestLogFailureBucket(Category.unsupportedModel) == .unsupported)
        #expect(AIRequestLogFailureBucket(Category.invalidStructuredResponse) == .invalidResponse)
    }

    @Test("content descriptors for the user's attempt and the reference sentence exist")
    func descriptorsExist() {
        let all = Set(AIRequestContentDescriptor.allCases)
        #expect(all.contains(.practiceAttempt))
        #expect(all.contains(.backtranslationReferenceSentence))
    }
}
