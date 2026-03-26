import Foundation
import AuthenticationServices

struct ServerResponse: Decodable {
    let success: Bool
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
            print("[UPLOAD] No server configured, skipping upload")
            return ""
        }

        // Check if token exists and is not expired
        if config.token(for: config.serverURL) == nil || config.isTokenExpired(for: config.serverURL) {
            print("[UPLOAD] Token missing or expired, starting OAuth2 flow")
            do {
                try await authenticateOAuth2(config: config)
            } catch {
                print("[UPLOAD] OAuth2 authentication failed: \(error)")
                return ""
            }
        }

        // Upload the file
        guard let token = config.token(for: config.serverURL) else {
            print("[UPLOAD] Still no token after authentication")
            return ""
        }

        return try await uploadToServer(imageURL: imageURL, token: token, config: config)
    }

    private func authenticateOAuth2(config: AppConfig) async throws {
        let authServer = LocalAuthServer()

        guard let authURL = authServer.getAuthURL(for: config.serverURL) else {
            throw NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
        }

        // Check if already authenticated (GET with no auto-redirect)
        let checkURL = authURL
        var checkRequest = URLRequest(url: checkURL)
        checkRequest.httpMethod = "GET"
        checkRequest.httpShouldHandleCookies = true

        do {
            let (_, checkResponse) = try await URLSession.shared.data(for: checkRequest)

            if let httpResponse = checkResponse as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("[OAUTH] Already authenticated - skipping OAuth flow")
                    return
                } else if (300...399).contains(httpResponse.statusCode) {
                    print("[OAUTH] Not authenticated - need to authenticate via OAuth")
                } else {
                    throw NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected auth response: \(httpResponse.statusCode)"])
                }
            }
        } catch {
            print("[OAUTH] Auth check failed: \(error)")
            throw error
        }

        // Start listening for callback in background
        let callbackTask = Task {
            try await authServer.listenForCallback()
        }

        // Open browser for authentication
        print("[OAUTH] Opening browser for OAuth: \(authURL)")
        NSWorkspace.shared.open(authURL)

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
        print("[OAUTH] ✓ Token obtained and saved (expires \(expiresAt))")
    }

    private func uploadToServer(imageURL: URL, token: String, config: AppConfig) async throws -> String {
        var request = URLRequest(url: URL(string: "\(config.serverURL)/api/ss/uploadScreenShot")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add title field (empty)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        print("[UPLOAD] Response status: \(httpResponse.statusCode)")

        let decoder = JSONDecoder()
        let serverResponse = try decoder.decode(ServerResponse.self, from: data)

        if serverResponse.success, let outputURL = serverResponse.output {
            print("[UPLOAD] ✓ Upload successful!")

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
            print("[UPLOAD] ✗ Upload failed: \(errorMsg)")
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
