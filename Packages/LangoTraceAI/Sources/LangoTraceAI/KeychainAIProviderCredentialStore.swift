import Foundation
import LangoTraceCore
import LocalAuthentication
import Security

public struct KeychainAIProviderCredentialStore: AIProviderCredentialStore {
    public init() {}

    public func upsertSecret(
        _ secret: AIProviderSecretInput,
        for reference: AIProviderCredentialKeychainReference
    ) async throws {
        let data = Data(secret.value.utf8)
        var addQuery = baseQuery(for: reference)
        addQuery[kSecValueData as String] = data
        if let accessible = accessibleValue(for: reference.accessibility) {
            addQuery[kSecAttrAccessible as String] = accessible
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                nonInteractiveQuery(for: reference) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw error(from: updateStatus)
            }
            return
        }

        throw error(from: addStatus)
    }

    public func hasSecret(
        for reference: AIProviderCredentialKeychainReference
    ) async -> AIProviderSecretPresence {
        var query = nonInteractiveQuery(for: reference)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return .present
        case errSecItemNotFound:
            return .missing
        case errSecInteractionNotAllowed:
            return .inaccessible
        default:
            return .inaccessible
        }
    }

    public func resolveSecret(
        for reference: AIProviderCredentialKeychainReference
    ) async throws -> AIProviderResolvedSecret {
        var query = nonInteractiveQuery(for: reference)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw error(from: status)
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            throw AIProviderCredentialStoreError.credentialCorrupted
        }
        return AIProviderResolvedSecret(value: value)
    }

    public func deleteSecret(
        for reference: AIProviderCredentialKeychainReference
    ) async throws {
        let status = SecItemDelete(nonInteractiveQuery(for: reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }
}

private func baseQuery(
    for reference: AIProviderCredentialKeychainReference
) -> [String: Any] {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: reference.service,
        kSecAttrAccount as String: reference.account,
        kSecAttrSynchronizable as String: reference.synchronizable ? kCFBooleanTrue as Any : kCFBooleanFalse as Any,
    ]
    if let accessGroup = reference.accessGroup {
        query[kSecAttrAccessGroup as String] = accessGroup
    }
    return query
}

private func nonInteractiveQuery(
    for reference: AIProviderCredentialKeychainReference
) -> [String: Any] {
    let context = LAContext()
    context.interactionNotAllowed = true

    var query = baseQuery(for: reference)
    query[kSecUseAuthenticationContext as String] = context
    query[secUseAuthenticationUIKey] = secUseAuthenticationUIFailValue
    return query
}

// Security.framework exposes these as kSecUseAuthenticationUI and kSecUseAuthenticationUIFail.
// The value constant is deprecated on modern SDKs, but macOS login keychain ACL prompts still
// honor it as the explicit no-UI fallback when LAContext.interactionNotAllowed is not enough.
private let secUseAuthenticationUIKey = "u_AuthUI"
private let secUseAuthenticationUIFailValue = "u_AuthUIF"

private func accessibleValue(for value: String) -> CFString? {
    switch value {
    case "when_unlocked_this_device_only":
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    case "after_first_unlock_this_device_only":
        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    default:
        nil
    }
}

private func error(from status: OSStatus) -> AIProviderCredentialStoreError {
    switch status {
    case errSecItemNotFound:
        .missingCredential
    case errSecInteractionNotAllowed:
        .credentialInaccessible
    case errSecDecode:
        .credentialCorrupted
    case errSecUserCanceled, errSecAuthFailed:
        .userInteractionRequired
    default:
        .credentialInaccessible
    }
}
