import Foundation
import AuthenticationServices

struct ServerResponse: Decodable {
    let success: Bool?
    let output: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, output, error
    }
}

@MainActor
final class UploadManager: NSObject {
    static let shared = UploadManager()

    func upload(imageURL: URL, config: AppConfig) async throws -> String {
        guard !config.serverURL.isEmpty else {
            // No server configured, just keep clipboard copy
            AppLogger.shared.log("[UPLOAD] No server configured, skipping upload")
            return ""
        }

        // Check if token exists and is not expired
        if config.token(for: config.serverURL) == nil || config.isTokenExpired(for: config.serverURL) {
            AppLogger.shared.log("[UPLOAD] Token missing or expired, starting OAuth2 flow")
            do {
                try await authenticateOAuth2(config: config)
            } catch {
                AppLogger.shared.log("[UPLOAD] OAuth2 authentication failed: \(error)")
                return ""
            }
        }

        // Upload the file
        guard let token = config.token(for: config.serverURL) else {
            AppLogger.shared.log("[UPLOAD] Still no token after authentication")
            return ""
        }

        do {
            return try await uploadToServer(imageURL: imageURL, token: token, config: config)
        } catch let error as NSError where error.domain == "Upload" && error.code == 401 {
            // Server rejected token (e.g. JWE expired server-side); clear and re-auth once
            AppLogger.shared.log("[UPLOAD] Server returned 401, clearing token and re-authenticating")
            config.deleteToken(for: config.serverURL)
            do {
                try await authenticateOAuth2(config: config)
            } catch {
                AppLogger.shared.log("[UPLOAD] Re-authentication failed: \(error)")
                return ""
            }
            guard let freshToken = config.token(for: config.serverURL) else {
                AppLogger.shared.log("[UPLOAD] Still no token after re-authentication")
                return ""
            }
            return try await uploadToServer(imageURL: imageURL, token: freshToken, config: config)
        }
    }

    private func authenticateOAuth2(config: AppConfig) async throws {
        let authServer = LocalAuthServer()

        guard let authURL = authServer.getAuthURL(for: config.serverURL) else {
            throw NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
        }

        // Note: When sending ?redirect_uri, server always responds with 3xx redirect
        // The browser will handle the redirect chain and eventually hit our localhost listener

        // Start listening for callback (this must happen BEFORE opening browser)
        AppLogger.shared.log("[OAUTH] Starting OAuth2 listener on localhost:52805")

        let callbackTask = Task {
            try await authServer.listenForCallback()
        }

        // Small delay to let background queue start, then wait for socket to be ready
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms for queue to dispatch
        try authServer.waitUntilReady(timeout: 10)

        // NOW open browser for authentication (socket is ready)
        AppLogger.shared.log("[OAUTH] Opening Chrome for OAuth")
        AppLogger.shared.log("[OAUTH] URL: \(authURL.absoluteString)")

        let chromeBundleID = "com.google.Chrome"
        var identifiers: NSArray?
        let success = NSWorkspace.shared.open([authURL], withAppBundleIdentifier: chromeBundleID, options: [], additionalEventParamDescriptor: nil, launchIdentifiers: &identifiers)
        if !success {
            AppLogger.shared.log("[OAUTH] ✗ Failed to open URL in Chrome, trying default browser")
            let fallback = NSWorkspace.shared.open(authURL)
            if !fallback {
                throw NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open browser"])
            }
        }
        AppLogger.shared.log("[OAUTH] ✓ Browser opened")

        // Wait for callback with 1 minute timeout (matching C# implementation)
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
            throw NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication timeout after 1 minute"])
        }

        // Race the callback task against timeout
        let (token, expiresAt): (String, Date)
        do {
            (token, expiresAt) = try await callbackTask.value
            timeoutTask.cancel()
        } catch {
            timeoutTask.cancel()
            throw error
        }

        config.saveToken(token, expiry: expiresAt, for: config.serverURL)
        AppLogger.shared.log("[OAUTH] ✓ Token obtained and saved (expires \(expiresAt))")
    }

    private func uploadToServer(imageURL: URL, token: String, config: AppConfig) async throws -> String {
        let rawURL = "\(config.serverURL)/api/ss/uploadScreenShot"
        AppLogger.shared.log("[UPLOAD] Target URL: '\(rawURL)'")
        guard let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            AppLogger.shared.log("[UPLOAD] ✗ Invalid server URL: '\(rawURL)'")
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL: \(rawURL)"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add title field (from active window)
        let windowTitle = WindowMonitor.shared.getCurrentWindowTitle()
        AppLogger.shared.log("[UPLOAD] Window title: \(windowTitle.isEmpty ? "(empty)" : windowTitle)")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append((windowTitle).data(using: .utf8) ?? Data())
        body.append("\r\n".data(using: .utf8)!)

        // Add image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"uploaded_image\"; filename=\"screenshot.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: imageURL))
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        request.timeoutInterval = 15

        AppLogger.shared.log("[UPLOAD] Sending request to \(config.serverURL)/api/ss/uploadScreenShot (\(body.count) bytes)")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        AppLogger.shared.log("[UPLOAD] Response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
            throw NSError(domain: "Upload", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }

        let decoder = JSONDecoder()
        let serverResponse = try decoder.decode(ServerResponse.self, from: data)

        if serverResponse.success == true, let outputURL = serverResponse.output {
            AppLogger.shared.log("[UPLOAD] ✓ Upload successful!")

            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(outputURL, forType: .string)

            // Play sound if enabled
            if config.enableSound {
                NSSound(named: "Glass")?.play()
            }

            return outputURL
        } else {
            let errorMsg = serverResponse.error ?? "Unknown error"
            AppLogger.shared.log("[UPLOAD] ✗ Upload failed: \(errorMsg)")
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }

    private static func extractToken(from url: URL) -> String? {
        return extractParameter(from: url, name: "token")
    }

    private static func extractParameter(from url: URL, name: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == name })?.value
    }
}

extension UploadManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
