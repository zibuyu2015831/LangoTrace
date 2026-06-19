import Foundation

/// Shared endpoint URL construction for all OpenAI-compatible request paths.
///
/// All services in this package must build request URLs through this helper so
/// that base URLs with or without trailing slashes, with path prefixes, or
/// already containing the operation suffix produce the same final URL in
/// probes and in real requests.
enum AIProviderEndpointURLBuilder {
    static func endpointURL(baseURL: String, pathSuffix: String) -> URL? {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = pathSuffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path: String = if basePath == suffix || basePath.hasSuffix("/" + suffix) {
            basePath
        } else {
            [basePath, suffix].filter { !$0.isEmpty }.joined(separator: "/")
        }
        components.path = "/" + path
        return components.url
    }
}
