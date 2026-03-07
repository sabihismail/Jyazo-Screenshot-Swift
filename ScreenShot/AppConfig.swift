import Foundation
import Security

@Observable
final class AppConfig {
    private let serviceName = "com.arkaprime.jyazo"

    var serverURL: String {
        get {
            UserDefaults.standard.string(forKey: "configServerURL") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "configServerURL")
        }
    }

    func token(for server: String) -> String? {
        let baseURL = extractBaseURL(server)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: baseURL,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveToken(_ token: String, expiry: Date, for server: String) {
        let baseURL = extractBaseURL(server)

        // Delete existing token first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: baseURL
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Save new token
        guard let tokenData = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: baseURL,
            kSecValueData as String: tokenData,
            kSecAttrLabel as String: "Jyazo OAuth2 Token"
        ]

        SecItemAdd(query as CFDictionary, nil)

        // Save expiry timestamp
        let expiryKey = "tokenExpiry_\(baseURL)"
        UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: expiryKey)
    }

    func isTokenExpired(for server: String) -> Bool {
        let baseURL = extractBaseURL(server)
        let expiryKey = "tokenExpiry_\(baseURL)"
        let expiry = UserDefaults.standard.double(forKey: expiryKey)

        guard expiry > 0 else { return true }
        return Date(timeIntervalSince1970: expiry) < Date()
    }

    private func extractBaseURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString.starts(with: "http") ? urlString : "http://\(urlString)") else {
            return urlString
        }
        return "\(url.scheme ?? "http")://\(url.host ?? "")"
    }
}
