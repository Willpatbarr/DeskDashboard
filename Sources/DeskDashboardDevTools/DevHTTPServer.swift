import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Development-only HTTP server: a minimal, dependency-free socket server
/// bound to loopback, just capable enough to serve the dev web renderer.
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

public enum DevHTTPServerError: Error {
    case socketFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
}

public final class DevHTTPServer: @unchecked Sendable {
    public let port: UInt16

    private let lock = NSLock()
    private var routes: [String: () -> DevHTTPResponse] = [:]
    private var serverSocket: Int32 = -1
    private var isListening = false

    public init(
        port: UInt16 = 8642
    ) {
        self.port = port
    }

    public func register(
        path: String,
        handler: @escaping () -> DevHTTPResponse
    ) {
        lock.lock()
        defer { lock.unlock() }
        routes[path] = handler
    }

    public func start() throws {
        signal(SIGPIPE, SIG_IGN)

        let fd = socket(AF_INET, SOCK_STREAM, 0)
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
        address.sin_addr = in_addr(
            s_addr: in_addr_t(UInt32(0x7F00_0001).bigEndian)
        )

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
                if errno == EINTR {
                    continue
                }
                return
            }

            respond(to: client)
        }
    }

    private func respond(
        to client: Int32
    ) {
        defer { close(client) }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let byteCount = read(client, &buffer, buffer.count)
        guard byteCount > 0 else {
            return
        }

        let request = String(
            decoding: buffer.prefix(byteCount),
            as: UTF8.self
        )
        let requestLine = request
            .split(separator: "\r\n", maxSplits: 1)
            .first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return
        }
        let path = String(parts[1].split(separator: "?").first ?? "/")

        lock.lock()
        let handler = routes[path]
        lock.unlock()

        let head: String
        let body: Data
        if let handler {
            let response = handler()
            body = response.body
            head = "HTTP/1.1 200 OK\r\n"
                + "Content-Type: \(response.contentType)\r\n"
                + "Content-Length: \(body.count)\r\n"
                + "Cache-Control: no-store\r\n"
                + "Connection: close\r\n\r\n"
        } else {
            body = Data("Not found".utf8)
            head = "HTTP/1.1 404 Not Found\r\n"
                + "Content-Type: text/plain\r\n"
                + "Content-Length: \(body.count)\r\n"
                + "Connection: close\r\n\r\n"
        }

        send(Data(head.utf8) + body, to: client)
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
