//
//  KeychainHelper.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/17/25.
//

import Foundation
import Security

enum KeychainError: Error { case unexpectedData, unhandled(OSStatus) }

struct KeychainHelper {
    private static let service = "com.enflow.keys"
    private static let account = "openai"

    static func save(_ value: String) throws {
        let data = Data(value.utf8)

        // Remove any existing item first (ignore errors)
        SecItemDelete([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)

        let status = SecItemAdd([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data
        ] as CFDictionary, nil)

        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    static func read() throws -> String {
        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true
        ] as CFDictionary, &item)

        guard status != errSecItemNotFound else { return "" }
        guard status == errSecSuccess,
              let data = item as? Data,
              let str  = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return str
    }
}
