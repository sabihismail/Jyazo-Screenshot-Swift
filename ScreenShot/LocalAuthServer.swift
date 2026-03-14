import Foundation

class LocalAuthServer {
    private let port: UInt16 = 52805

    func getAuthURL(for serverURL: String) -> URL? {
        let redirectUri = "http://127.0.0.1:\(port)/"

        guard var components = URLComponents(string: "\(serverURL)/api/authenticate") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: redirectUri)
        ]

        return components.url
    }

    func getRedirectUri() -> String {
        return "http://127.0.0.1:\(port)/"
    }
}
