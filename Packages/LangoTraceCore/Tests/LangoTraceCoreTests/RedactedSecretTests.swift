import LangoTraceCore
import Testing

@Test("RedactedSecret description does not contain plaintext")
func redactedSecretDescriptionDoesNotContainPlaintext() {
    let secret = RedactedSecret("sk-super-secret-key-12345")
    #expect(String(describing: secret) != "sk-super-secret-key-12345")
    #expect(String(describing: secret) == "<redacted>")
}

@Test("RedactedSecret debug description does not contain plaintext")
func redactedSecretDebugDescriptionDoesNotContainPlaintext() {
    let secret = RedactedSecret("sk-super-secret-key-12345")
    #expect(String(reflecting: secret) != "sk-super-secret-key-12345")
    #expect(String(reflecting: secret) == "<redacted>")
}

@Test("RedactedSecret Mirror does not expose plaintext")
func redactedSecretMirrorDoesNotExposePlaintext() {
    let secret = RedactedSecret("sk-super-secret-key-12345")
    let mirror = Mirror(reflecting: secret)
    #expect(mirror.children.isEmpty)
}

@Test("RedactedSecret string interpolation does not contain plaintext")
func redactedSecretStringInterpolationDoesNotContainPlaintext() {
    let secret = RedactedSecret("sk-super-secret-key-12345")
    let interpolated = "Secret: \(secret)"
    #expect(!interpolated.contains("sk-super-secret-key-12345"))
    #expect(interpolated.contains("<redacted>"))
}

@Test("RedactedSecret equal secrets compare as equal")
func redactedSecretEqualSecretsCompareAsEqual() {
    let a = RedactedSecret("same-key")
    let b = RedactedSecret("same-key")
    #expect(a == b)
}

@Test("RedactedSecret different secrets compare as not equal")
func redactedSecretDifferentSecretsCompareAsNotEqual() {
    let a = RedactedSecret("key-a")
    let b = RedactedSecret("key-b")
    #expect(a != b)
}

@Test("RedactedSecret different length secrets compare as not equal")
func redactedSecretDifferentLengthSecretsCompareAsNotEqual() {
    let a = RedactedSecret("short")
    let b = RedactedSecret("much-longer-key")
    #expect(a != b)
}

@Test("RedactedSecret empty string is valid and redacted")
func redactedSecretEmptyStringIsValidAndRedacted() {
    let secret = RedactedSecret("")
    #expect(String(describing: secret) == "<redacted>")
    #expect(secret == RedactedSecret(""))
}

@Test("RedactedSecret unsafeUnwrappedValue reveals plaintext")
func redactedSecretUnsafeUnwrappedValueRevealsPlaintext() {
    let secret = RedactedSecret("sk-super-secret-key-12345")
    #expect(secret.unsafeUnwrappedValue == "sk-super-secret-key-12345")
}

@Test("RedactedSecret optional nil description is nil")
func redactedSecretOptionalNilDescriptionIsNil() {
    let secret: RedactedSecret? = nil
    #expect(String(describing: secret) == "nil")
}

@Test("RedactedSecret optional non-nil description is redacted")
func redactedSecretOptionalNonNilDescriptionIsRedacted() {
    let secret: RedactedSecret? = RedactedSecret("sk-test")
    // Optional wrapping produces "Optional(<redacted>)", not "<redacted>"
    let described = String(describing: secret)
    #expect(!described.contains("sk-test"))
    #expect(described.contains("<redacted>"))
}
