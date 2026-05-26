import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Test("Keychain credential store upserts resolves updates and deletes secrets")
func keychainCredentialStoreUpsertsResolvesUpdatesAndDeletesSecrets() async throws {
    let store = KeychainAIProviderCredentialStore()
    let reference = testReference()
    try? await store.deleteSecret(for: reference)

    try await store.upsertSecret(AIProviderSecretInput(value: "first-secret"), for: reference)
    #expect(await store.hasSecret(for: reference) == .present)
    #expect(try await store.resolveSecret(for: reference).value == "first-secret")

    try await store.upsertSecret(AIProviderSecretInput(value: "rotated-secret"), for: reference)
    #expect(try await store.resolveSecret(for: reference).value == "rotated-secret")

    try await store.deleteSecret(for: reference)
    #expect(await store.hasSecret(for: reference) == .missing)
    await #expect(throws: AIProviderCredentialStoreError.missingCredential) {
        try await store.resolveSecret(for: reference)
    }
}

@Test("Keychain credential store reports missing credential without creating metadata")
func keychainCredentialStoreReportsMissingCredential() async {
    let store = KeychainAIProviderCredentialStore()
    let reference = testReference()
    try? await store.deleteSecret(for: reference)

    #expect(await store.hasSecret(for: reference) == .missing)
}

@Test("Keychain credential store uses noninteractive credential queries")
func keychainCredentialStoreUsesNoninteractiveCredentialQueries() throws {
    let source = try String(
        contentsOf: langoTraceAISourceFileURL(named: "KeychainAIProviderCredentialStore.swift"),
        encoding: .utf8
    )

    #expect(source.contains("kSecUseAuthenticationContext"))
    #expect(source.contains("interactionNotAllowed = true"))
    #expect(source.contains("nonInteractiveQuery(for: reference)"))
}

private func testReference() -> AIProviderCredentialKeychainReference {
    AIProviderCredentialKeychainReference(
        credentialID: UUID().uuidString,
        kind: .apiKey,
        service: "com.langotrace.ai-provider.tests"
    )
}

private func langoTraceAISourceFileURL(named filename: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/LangoTraceAI/\(filename)")
}
