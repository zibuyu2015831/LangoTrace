import LangoTraceCore

/// Shared mapping from non-2xx HTTP status codes to provider validation error
/// categories. All OpenAI-compatible request paths (configuration probes,
/// embedding probes, learning material generation, reading selection
/// explanation) must route through this helper so the same provider failure is
/// classified identically everywhere.
enum AIProviderHTTPStatusErrorMapper {
    static func errorCategory(forHTTPStatusCode statusCode: Int) -> AIProviderValidationErrorCategory {
        switch statusCode {
        case 401, 403:
            .authenticationFailed
        case 404:
            .unsupportedModel
        case 429:
            .rateLimited
        default:
            .providerRejected
        }
    }
}
