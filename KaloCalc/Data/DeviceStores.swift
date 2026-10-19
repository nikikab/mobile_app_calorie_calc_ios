import Foundation
import Security
import KaloCalcCore

/// Profile, goal choice and settings in UserDefaults.
final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }

    func string(_ key: String) -> String? { defaults.object(forKey: key) as? String }
    func int(_ key: String) -> Int? { defaults.object(forKey: key) as? Int }
    func double(_ key: String) -> Double? { defaults.object(forKey: key) as? Double }
    func bool(_ key: String) -> Bool? { defaults.object(forKey: key) as? Bool }
    func set(_ value: String, for key: String) { defaults.set(value, forKey: key) }
    func set(_ value: Int, for key: String) { defaults.set(value, forKey: key) }
    func set(_ value: Double, for key: String) { defaults.set(value, forKey: key) }
    func set(_ value: Bool, for key: String) { defaults.set(value, forKey: key) }
}

/// The Gemini API key in the Keychain. It stays on this device (not synced, not in backups to other devices) and
/// is readable only while the phone is unlocked.
final class KeychainSecretStore: SecretStore {
    private let service: String
    init(service: String = "com.nikikabadzhov.kalocalc") { self.service = service }

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    func secret(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setSecret(_ value: String?, for key: String) {
        SecItemDelete(query(key) as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var q = query(key)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
