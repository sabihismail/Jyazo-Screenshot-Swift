import Foundation
import Security
import Observation

@Observable
final class AppConfig {
    private let serviceName = "com.arkaprime.jyazo"

    // MARK: - Server & Authentication
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    // MARK: - Image Capture Shortcuts
    var enableImageShortcut: Bool {
        didSet { UserDefaults.standard.set(enableImageShortcut, forKey: "enableImageShortcut") }
    }

    var imageShortcutKey: String {
        didSet { UserDefaults.standard.set(imageShortcutKey, forKey: "imageShortcutKey") }
    }

    var imageShortcutModifiers: UInt {
        didSet { UserDefaults.standard.set(imageShortcutModifiers, forKey: "imageShortcutModifiers") }
    }

    // MARK: - GIF Recording Shortcuts
    var enableGIFShortcut: Bool {
        didSet { UserDefaults.standard.set(enableGIFShortcut, forKey: "enableGIFShortcut") }
    }

    var gifShortcutKey: String {
        didSet { UserDefaults.standard.set(gifShortcutKey, forKey: "gifShortcutKey") }
    }

    var gifShortcutModifiers: UInt {
        didSet { UserDefaults.standard.set(gifShortcutModifiers, forKey: "gifShortcutModifiers") }
    }

    // MARK: - File Saving
    var saveAllImages: Bool {
        didSet { UserDefaults.standard.set(saveAllImages, forKey: "saveAllImages") }
    }

    var saveDirectory: String {
        didSet { UserDefaults.standard.set(saveDirectory, forKey: "saveDirectory") }
    }

    // MARK: - Sound & GIF Settings
    var enableSound: Bool {
        didSet { UserDefaults.standard.set(enableSound, forKey: "enableSound") }
    }

    var gifFrameRate: Int {
        didSet { UserDefaults.standard.set(gifFrameRate, forKey: "gifFrameRate") }
    }

    init() {
        let defaults = UserDefaults.standard

        self.serverURL = defaults.string(forKey: "serverURL") ?? ""
        self.enableImageShortcut = defaults.bool(forKey: "enableImageShortcut")
        self.imageShortcutKey = defaults.string(forKey: "imageShortcutKey") ?? "c"
        self.imageShortcutModifiers = UInt(defaults.integer(forKey: "imageShortcutModifiers"))
        self.enableGIFShortcut = defaults.bool(forKey: "enableGIFShortcut")
        self.gifShortcutKey = defaults.string(forKey: "gifShortcutKey") ?? "g"
        self.gifShortcutModifiers = UInt(defaults.integer(forKey: "gifShortcutModifiers"))
        self.saveAllImages = defaults.bool(forKey: "saveAllImages")
        self.saveDirectory = defaults.string(forKey: "saveDirectory") ?? Self.defaultSaveDirectory()
        self.enableSound = defaults.bool(forKey: "enableSound")
        self.gifFrameRate = defaults.integer(forKey: "gifFrameRate") > 0 ? defaults.integer(forKey: "gifFrameRate") : 10
    }

    static func defaultSaveDirectory() -> String {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        return picturesURL.appendingPathComponent("Jyazo").path
    }

    // MARK: - Keychain Token Management
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

    func deleteToken(for server: String) {
        let baseURL = extractBaseURL(server)

        // Delete from Keychain
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: baseURL
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Delete expiry from UserDefaults
        let expiryKey = "tokenExpiry_\(baseURL)"
        UserDefaults.standard.removeObject(forKey: expiryKey)

        print("[AUTH] Deleted token for \(baseURL)")
    }

    private func extractBaseURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString.starts(with: "http") ? urlString : "http://\(urlString)") else {
            return urlString
        }
        return "\(url.scheme ?? "http")://\(url.host ?? "")"
    }
}
