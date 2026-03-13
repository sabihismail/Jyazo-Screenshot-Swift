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

    private var authSession: ASWebAuthenticationSession?
    private var authServer: LocalAuthServer?

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
        // Start local server to receive OAuth callback
        let authServer = LocalAuthServer()
        self.authServer = authServer

        let (token, expiresAt) = try await authServer.startAndWait()

        // Now open the auth URL in browser
        return try await withCheckedThrowingContinuation { continuation in
            let redirectUri = authServer.getRedirectUri()

            guard var components = URLComponents(string: "\(config.serverURL)/api/authenticate") else {
                continuation.resume(throwing: NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"]))
                return
            }

            components.queryItems = [
                URLQueryItem(name: "redirect_uri", value: redirectUri)
            ]

            guard let authURL = components.url else {
                continuation.resume(throwing: NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not build auth URL"]))
                return
            }

            print("[UPLOAD] Opening browser for OAuth2: \(authURL)")
            NSWorkspace.shared.open(authURL)

            // Token already received from local server
            config.saveToken(token, expiry: expiresAt, for: config.serverURL)
            print("[UPLOAD] ✓ Token obtained and saved (expires \(expiresAt))")
            continuation.resume()
        }
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
