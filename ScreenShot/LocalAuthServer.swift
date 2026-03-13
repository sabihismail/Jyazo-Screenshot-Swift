import Foundation

class LocalAuthServer {
    private var server: HTTPServer?
    private let port: UInt16 = 52805

    func startAndWait() async throws -> (token: String, expiresAt: Date) {
        return try await withCheckedThrowingContinuation { continuation in
            let server = HTTPServer(port: port) { [weak self] token, expiresAt in
                self?.stop()
                continuation.resume(returning: (token: token, expiresAt: expiresAt))
            } onError: { error in
                continuation.resume(throwing: error)
            }

            do {
                try server.start()
                self.server = server
                print("[AUTH] Local server listening on http://127.0.0.1:\(self.port)")
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func stop() {
        server?.stop()
        server = nil
    }

    func getRedirectUri() -> String {
        return "http://127.0.0.1:\(port)/"
    }
}

private class HTTPServer {
    private let port: UInt16
    private var listener: try? NWListener
    private let onSuccess: (String, Date) -> Void
    private let onError: (Error) -> Void

    init(port: UInt16, onSuccess: @escaping (String, Date) -> Void, onError: @escaping (Error) -> Void) {
        self.port = port
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func start() throws {
        let socket = socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { throw NSError(domain: "socket", code: -1) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK)

        var reuse: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        guard bind(socket, UnsafeMutableRawPointer(&addr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size)) >= 0 else {
            close(socket)
            throw NSError(domain: "bind", code: -1)
        }

        guard listen(socket, 1) >= 0 else {
            close(socket)
            throw NSError(domain: "listen", code: -1)
        }

        // Accept connection in background
        DispatchQueue.global().async { [weak self] in
            self?.acceptConnection(socket: socket)
        }
    }

    private func acceptConnection(socket: Int32) {
        var addr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)

        let client = accept(socket, UnsafeMutableRawPointer(&addr).assumingMemoryBound(to: sockaddr.self), &len)
        close(socket)

        guard client >= 0 else { return }

        // Read request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(client, &buffer, buffer.count)

        guard bytesRead > 0 else {
            close(client)
            return
        }

        let request = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
        print("[AUTH] Received request: \(request.split(separator: "\n").first ?? "")")

        // Parse query string from request
        if let urlStart = request.range(of: "GET "),
           let urlEnd = request.range(of: " HTTP") {
            let path = String(request[urlStart.upperBound..<urlEnd.lowerBound])

            if let components = URLComponents(string: "http://localhost" + path),
               let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
               let expiresAtStr = components.queryItems?.first(where: { $0.name == "expiresAt" })?.value,
               let expiresAt = TimeInterval(expiresAtStr) {

                let expiry = Date(timeIntervalSince1970: expiresAt)

                // Send response
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: 50\r\n\r\n<html><body>Authentication successful!</body></html>"
                let _ = write(client, response, response.count)

                DispatchQueue.main.async {
                    self.onSuccess(token, expiry)
                }
            } else if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
                let response = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
                let _ = write(client, response, response.count)

                DispatchQueue.main.async {
                    self.onError(NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
                }
            }
        }

        close(client)
    }

    func stop() {
        // Server stops automatically when connections are closed
    }
}

// Import socket APIs
import Darwin

let SO_REUSEADDR = 0x0004
let INADDR_LOOPBACK: in_addr_t = 0x7f000001
