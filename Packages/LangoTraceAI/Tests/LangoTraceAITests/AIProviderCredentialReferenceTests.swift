import LangoTraceAI
import LangoTraceCore
import Testing

@Test("Credential Keychain reference uses stable credential id and kind")
func credentialKeychainReferenceUsesStableCredentialIDAndKind() {
    let reference = AIProviderCredentialKeychainReference(
        credentialID: "credential-1",
        kind: .apiKey
    )

    #expect(reference.service == "com.langotrace.ai-provider")
    #expect(reference.account == "ai-provider-credential:credential-1:api_key")
    #expect(reference.synchronizable == false)
}

@Test("Credential resolver returns resolved secret without exposing it in metadata")
func credentialResolverReturnsResolvedSecretWithoutExposingItInMetadata() async throws {
    let store = InMemoryAIProviderCredentialStore()
    let reference = AIProviderCredentialKeychainReference(
        credentialID: "credential-1",
        kind: .apiKey
    )
    try await store.upsertSecret(
        AIProviderSecretInput(value: "sk-test"),
        for: reference
    )

    let resolver = AIProviderCredentialResolver(store: store)
    let resolved = try await resolver.resolve(reference)

    #expect(resolved.value == "sk-test")
    #expect(await store.hasSecret(for: reference) == .present)
}
