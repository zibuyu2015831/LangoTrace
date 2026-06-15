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

@Test("Keychain credential store resolves credential round-trips with special characters")
func keychainCredentialStoreRoundTripsSpecialCharacters() async throws {
    let store = KeychainAIProviderCredentialStore()
    let reference = testReference()
    try? await store.deleteSecret(for: reference)

    let special = "sk-proj-αβγ-日本語-🔐-with-dashes_and.underscores"
    try await store.upsertSecret(AIProviderSecretInput(value: special), for: reference)
    #expect(try await store.resolveSecret(for: reference).value == special)

    try await store.deleteSecret(for: reference)
}

// MARK: - Non-interactive query behavior notes
//
// The following Keychain security behaviors are enforced by the production code
// but cannot be directly verified through behavioral unit tests without an
// injectable query executor seam:
//
// 1. Non-interactive queries: All Keychain queries include kSecUseAuthenticationContext
//    with LAContext.interactionNotAllowed = true and kSecUseAuthenticationUI =
//    kSecUseAuthenticationUIFail to prevent system authentication prompts.
//
// 2. Platform-appropriate accessibility: On iOS, items use kSecAttrAccessible
//    (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly); on macOS, the accessibility
//    attribute is intentionally omitted because the login keychain handles it.
//
// 3. macOS trusted access: New login keychain items on macOS get a SecAccess ACL
//    via dlopen + SecAccessCreate to allow the current app to read without prompts.
//    See docs/architecture/notes/2026-06-05-macos-ai-provider-credential-signing-notes.md
//    for the migration plan to kSecUseDataProtectionKeychain.
//
// Verifying these requires either:
// (a) An injectable SecItem query executor protocol (deferred to E0b), or
// (b) Manual verification on macOS with the Keychain Access utility.
//
// The previous source-grep pseudo-tests that read the .swift file and asserted
// substring presence have been removed per plan Phase 5 step 3.

private func testReference() -> AIProviderCredentialKeychainReference {
    AIProviderCredentialKeychainReference(
        credentialID: UUID().uuidString,
        kind: .apiKey,
        service: "com.langotrace.ai-provider.tests"
    )
}
