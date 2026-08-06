// PushMusicService.swift — Music source (production): latest now-playing pushed over HTTP.

import DashboardKit
import Foundation

// MARK: - Push source (production: fed by the /ingest endpoint)

/// Push-backed source: holds the most recent now-playing value pushed in from
/// outside (a producer POSTing to /ingest/now-playing). Thread safe — updates
/// arrive on a server thread while the widget reads on main.
public final class PushMusicService: MusicService, @unchecked Sendable {
    private let lock = NSLock()
    private var latest: NowPlaying?

    public init(
        initialNowPlaying: NowPlaying? = nil
    ) {
        self.latest = initialNowPlaying
    }

    public func update(
        _ nowPlaying: NowPlaying?
    ) {
        lock.lock()
        latest = nowPlaying
        lock.unlock()
    }

    public func nowPlaying() -> NowPlaying? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }
}
