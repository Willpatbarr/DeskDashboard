// PushClaudeSessionsService.swift — Claude sessions source (production): pushed over HTTP, focus calls back.

import DashboardKit
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Push-backed source: holds the most recent session board pushed in from the
/// Mac's AgentManager daemon (POST /ingest/claude-sessions), and sends focus
/// taps back to that daemon. Thread safe — pushes arrive on a server thread,
/// the widget reads on main, and focus fires from the tap path.
public final class PushClaudeSessionsService: ClaudeSessionsService, @unchecked Sendable {
    private let lock = NSLock()
    private var latest: ClaudeSessionsReading?
    /// Focus taps waiting for the Mac to collect them (see `drainPendingFocus`).
    private var pendingFocus: [String] = []
    /// Base URL of the AgentManager daemon on the Mac (e.g. `http://mac.local:8790`).
    /// When set, taps POST straight to the Mac. When nil — the default, and the
    /// right choice for a Mac whose firewall drops incoming connections — taps
    /// are queued here instead, and the Mac's own poll drains them (it can
    /// always reach US; we may not be able to reach IT).
    private let agentManagerBaseURL: URL?
    private let session: URLSession

    public init(
        agentManagerBaseURL: URL? = nil,
        initialReading: ClaudeSessionsReading? = nil,
        session: URLSession = .shared
    ) {
        self.agentManagerBaseURL = agentManagerBaseURL
        self.latest = initialReading
        self.session = session
    }

    public func update(_ reading: ClaudeSessionsReading?) {
        lock.lock()
        latest = reading
        lock.unlock()
    }

    public func reading() -> ClaudeSessionsReading? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    /// Hand the queued focus taps to the Mac and clear the queue. Served by the
    /// GET /claude-focus-queue route — a destructive read, which is fine for a
    /// single-consumer personal appliance.
    public func drainPendingFocus() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let drained = pendingFocus
        pendingFocus = []
        return drained
    }

    public func focus(sessionID: String) {
        guard let base = agentManagerBaseURL,
              let url = URL(string: "/api/focus/\(sessionID)", relativeTo: base) else {
            // Queue for the Mac's next poll of /claude-focus-queue.
            lock.lock()
            pendingFocus.append(sessionID)
            lock.unlock()
            print("[claude-sessions] focus \(sessionID) queued for pickup")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        // Fire-and-forget off the tap path; a stale session id just 404s on the
        // Mac, which must never bring the kiosk down.
        let task = session.dataTask(with: request) { _, response, error in
            if let error {
                print("[claude-sessions] focus \(sessionID) failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("[claude-sessions] focus \(sessionID) -> HTTP \(http.statusCode)")
            } else {
                print("[claude-sessions] focus \(sessionID) -> ok")
            }
        }
        task.resume()
    }
}
