import Foundation

class LocalAuthServer {
    private let port: UInt16 = 52805
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let readySignal = DispatchSemaphore(value: 0)

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

    func waitUntilReady(timeout: TimeInterval = 10) throws {
        print("[AUTH] Waiting for socket to be ready (timeout: \(timeout)s)")
        let result = readySignal.wait(timeout: .now() + timeout)
        if result == .timedOut {
            throw NSError(domain: "socket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Socket failed to start listening within \(timeout)s"])
        }
        print("[AUTH] Socket is ready")
    }

    func listenForCallback() async throws -> (token: String, expiresAt: Date) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "socket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server deallocated"]))
                    return
                }

                do {
                    let result = try self.startListening()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startListening() throws -> (token: String, expiresAt: Date) {
        print("[AUTH] Listening for callback on localhost:\(port)")

        // Create socket
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw NSError(domain: "socket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }

        defer { Darwin.close(socket) }

        // Set socket options
        var reuseAddr: Int32 = 1
        Darwin.setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Bind socket
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16HostToBig(port)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            Darwin.bind(socket, UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
        }

        guard bindResult >= 0 else {
            throw NSError(domain: "bind", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to bind socket"])
        }

        // Listen
        guard Darwin.listen(socket, 1) >= 0 else {
            throw NSError(domain: "listen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to listen on socket"])
        }

        // Signal that socket is ready
        print("[AUTH] ✓ Socket listening, ready for connections")
        readySignal.signal()

        // Accept connection
        var clientAddr = sockaddr_in()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let client = withUnsafeMutablePointer(to: &clientAddr) { ptr in
            Darwin.accept(socket, UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self), &clientAddrLen)
        }

        guard client >= 0 else {
            throw NSError(domain: "accept", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to accept connection"])
        }

        defer { Darwin.close(client) }

        // Read request
        var buffer = [UInt8](repeating: 0, count: 2048)
        let bytesRead = Darwin.read(client, &buffer, buffer.count)

        guard bytesRead > 0 else {
            throw NSError(domain: "read", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read from socket"])
        }

        let request = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
        print("[AUTH] Received callback request")

        // Parse request line to extract path
        let lines = request.split(separator: "\n")
        guard let firstLine = lines.first else {
            throw NSError(domain: "parse", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid request"])
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            throw NSError(domain: "parse", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid request line"])
        }

        let path = String(parts[1])

        // Parse query parameters
        guard let urlComponents = URLComponents(string: "http://localhost" + path),
              let token = urlComponents.queryItems?.first(where: { $0.name == "token" })?.value,
              let expiresAtStr = urlComponents.queryItems?.first(where: { $0.name == "expiresAt" })?.value,
              let expiresAtInterval = TimeInterval(expiresAtStr) else {
            // Send error response
            let response = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
            Darwin.write(client, response, response.count)
            throw NSError(domain: "OAuth2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing token or expiry in callback"])
        }

        // Send success response
        let successHtml = "<html><body><h1>Authentication Successful</h1><p>You can close this window.</p></body></html>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(successHtml.count)\r\n\r\n\(successHtml)"
        Darwin.write(client, response, response.count)

        let expiresAt = Date(timeIntervalSince1970: expiresAtInterval)
        print("[AUTH] Token received, expires: \(expiresAt)")

        return (token: token, expiresAt: expiresAt)
    }
}

// Darwin imports
import Darwin
