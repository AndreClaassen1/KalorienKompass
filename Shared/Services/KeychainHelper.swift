//
//  KeychainHelper.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation
import Security

/// Keychain-Wrapper fuer sichere Speicherung von API-Keys
enum KeychainHelper {
    private nonisolated static let service = "de.andreclaassen.KalorienKompass"
    private nonisolated static let apiKeyAccount = "anthropic-api-key"

    /// Speichert den API-Key im Keychain
    static func saveAPIKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }

        // Bestehenden Eintrag loeschen
        deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    /// Liest den API-Key aus dem Keychain
    nonisolated static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Loescht den API-Key aus dem Keychain
    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Prueft ob ein API-Key vorhanden ist (Keychain oder Bundle-Injection)
    static var hasAPIKey: Bool {
        if let bundleKey = Bundle.main.infoDictionary?["ClaudeAPIKey"] as? String,
           !bundleKey.isEmpty, !bundleKey.hasPrefix("$(") {
            return true
        }
        return loadAPIKey() != nil
    }

    /// Maskierte Anzeige des API-Keys (letzte 4 Zeichen)
    static var maskedAPIKey: String? {
        guard let key = loadAPIKey(), key.count > 4 else { return nil }
        let suffix = String(key.suffix(4))
        return String(repeating: "\u{2022}", count: 12) + suffix
    }
}
