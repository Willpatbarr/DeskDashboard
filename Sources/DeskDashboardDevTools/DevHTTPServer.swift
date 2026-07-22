import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// glibc imports `SOCK_STREAM` as the `__socket_type` enum rather than `Int32`
// (Darwin and musl both type it as `Int32`), so `socket()`'s type argument
// needs an explicit conversion there.
#if canImport(Glibc)
private let sockStreamType = Int32(SOCK_STREAM.rawValue)
#else
private let sockStreamType = SOCK_STREAM
#endif

// A minimal, dependency-free HTTP server for development only. Not part of the
// shipping dashboard — it exists so the dev web renderer and the sensor-ingest
// endpoint have something to talk to during development.

// MARK: - Response

/// A response body + content type returned by a route handler.
public struct DevHTTPResponse {
    public var contentType: String
    public var body: Data

    public init(
        contentType: String,
        body: Data
    ) {
        self.contentType = contentType
        self.body = body
    }
}

// MARK: - Errors

public enum DevHTTPServerError: Error {
    case socketFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
}

// MARK: - Server

/// Dependency-free socket server bound to all interfaces (INADDR_ANY) so LAN
/// devices — e.g. a phone running a Shortcut — can reach it.
public final class DevHTTPServer: @unchecked Sendable {
    public let port: UInt16

    private let lock = NSLock()
    private var routes: [String: () -> DevHTTPResponse] = [:]
    private var postRoutes: [String: (Data) -> DevHTTPResponse] = [:]
    private var serverSocket: Int32 = -1
    private var isListening = false

    public init(
        port: UInt16 = 8642
    ) {
        self.port = port
    }

    // MARK: - Route registration

    public func register(
        path: String,
        handler: @escaping () -> DevHTTPResponse
    ) {
        lock.lock()
        defer { lock.unlock() }
        routes[path] = handler
    }

    /// Register a handler for POST requests to `path`; it receives the raw
    /// request body.
    public func registerPost(
        path: String,
        handler: @escaping (Data) -> DevHTTPResponse
    ) {
        lock.lock()
        defer { lock.unlock() }
        postRoutes[path] = handler
    }

    // MARK: - Lifecycle

    public func start() throws {
        signal(SIGPIPE, SIG_IGN)

        let fd = socket(AF_INET, sockStreamType, 0)
        guard fd >= 0 else {
            throw DevHTTPServerError.socketFailed(errno)
        }

        var reuse: Int32 = 1
        setsockopt(
            fd,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        // INADDR_ANY (0.0.0.0): listen on all interfaces so LAN clients connect.
        address.sin_addr = in_addr(s_addr: in_addr_t(0))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw DevHTTPServerError.bindFailed(errno)
        }

        guard listen(fd, 16) == 0 else {
            close(fd)
            throw DevHTTPServerError.listenFailed(errno)
        }

        lock.lock()
        serverSocket = fd
        isListening = true
        lock.unlock()

        Thread.detachNewThread { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        lock.lock()
        isListening = false
        let socket = serverSocket
        serverSocket = -1
        lock.unlock()

        if socket >= 0 {
            close(socket)
        }
    }

    // MARK: - Accept loop

    private func acceptLoop() {
        while true {
            lock.lock()
            let socket = serverSocket
            let listening = isListening
            lock.unlock()

            guard listening, socket >= 0 else {
                return
            }

            let client = accept(socket, nil, nil)
            guard client >= 0 else {
                // A failed accept (interrupted syscall, aborted/probed
                // connection) must not kill the server — keep listening
                // as long as we haven't been explicitly stopped.
                lock.lock()
                let stillListening = isListening
                lock.unlock()
                if stillListening {
                    continue
                }
                return
            }

            // Handle each connection on its own thread so a slow or
            // misbehaving client can't block or corrupt the accept loop.
            Thread.detachNewThread { [weak self] in
                self?.respond(to: client)
            }
        }
    }

    // MARK: - Request handling

    private func respond(
        to client: Int32
    ) {
        defer { close(client) }

        // Read until the end of the request headers (blank line), then keep
        // reading until the full Content-Length body has arrived — the body
        // often lands in a later TCP segment than the headers.
        var raw = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while raw.range(of: Data([13, 10, 13, 10])) == nil, raw.count < 65_536 {
            let byteCount = read(client, &chunk, chunk.count)
            guard byteCount > 0 else {
                break
            }
            raw.append(contentsOf: chunk[0..<byteCount])
        }
        guard !raw.isEmpty else {
            return
        }

        if let headerEnd = raw.range(of: Data([13, 10, 13, 10])) {
            let headerText = String(decoding: raw[raw.startIndex..<headerEnd.lowerBound], as: UTF8.self)
            let contentLength = Self.contentLength(in: headerText)

            // Many HTTP clients (incl. iOS URLSession) send "Expect: 100-continue"
            // and withhold the body until the server acknowledges. Send the
            // interim response so the body actually arrives.
            if contentLength > 0, headerText.lowercased().contains("expect: 100-continue") {
                send(Data("HTTP/1.1 100 Continue\r\n\r\n".utf8), to: client)
            }

            var bodyReceived = raw.distance(from: headerEnd.upperBound, to: raw.endIndex)
            while bodyReceived < contentLength, raw.count < 1_048_576 {
                let byteCount = read(client, &chunk, chunk.count)
                guard byteCount > 0 else {
                    break
                }
                raw.append(contentsOf: chunk[0..<byteCount])
                bodyReceived += byteCount
            }
        }

        let request = String(decoding: raw, as: UTF8.self)
        let requestLine = request
            .split(separator: "\r\n", maxSplits: 1)
            .first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return
        }
        let method = String(parts[0])
        let path = String(parts[1].split(separator: "?").first ?? "/")

        let head: String
        let body: Data

        if method == "POST" {
            lock.lock()
            let handler = postRoutes[path]
            lock.unlock()

            // Body is everything after the blank line separating headers.
            // (Dev-only: assumes small bodies that arrive in one read.)
            let requestBody: Data
            if let separator = raw.range(of: Data([13, 10, 13, 10])) {
                requestBody = raw.subdata(in: separator.upperBound..<raw.endIndex)
            } else {
                requestBody = Data()
            }

            if let handler {
                let response = handler(requestBody)
                body = response.body
                head = ok(contentType: response.contentType, length: body.count)
            } else {
                (head, body) = notFound()
            }
        } else {
            lock.lock()
            let handler = routes[path]
            lock.unlock()

            if let handler {
                let response = handler()
                body = response.body
                head = ok(contentType: response.contentType, length: body.count)
            } else {
                (head, body) = notFound()
            }
        }

        send(Data(head.utf8) + body, to: client)
    }

    // MARK: - Helpers

    private static func contentLength(
        in headerText: String
    ) -> Int {
        for line in headerText.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" else {
                continue
            }
            return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return 0
    }

    private func ok(
        contentType: String,
        length: Int
    ) -> String {
        "HTTP/1.1 200 OK\r\n"
            + "Content-Type: \(contentType)\r\n"
            + "Content-Length: \(length)\r\n"
            + "Cache-Control: no-store\r\n"
            + "Connection: close\r\n\r\n"
    }

    private func notFound() -> (String, Data) {
        let body = Data("Not found".utf8)
        let head = "HTTP/1.1 404 Not Found\r\n"
            + "Content-Type: text/plain\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        return (head, body)
    }

    private func send(
        _ data: Data,
        to client: Int32
    ) {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else {
                return
            }

            var offset = 0
            while offset < raw.count {
                let written = write(client, base + offset, raw.count - offset)
                guard written > 0 else {
                    return
                }
                offset += written
            }
        }
    }
}
