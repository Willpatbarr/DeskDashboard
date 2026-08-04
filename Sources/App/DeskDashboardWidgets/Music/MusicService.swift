import DashboardKit
import Foundation

// Music — the DATA layer of the widget's Service -> WidgetModel -> Widget
// pipeline. Several interchangeable sources conform to `MusicService`; the
// widget never cares which one. This mirrors IndoorTemperature: the true
// "now playing" reading arrives over a network protocol (pyatv / AppleScript /
// MediaRemote) from an external producer POSTing to /ingest/now-playing —
// nothing here imports any media framework, so it runs on any platform.

// MARK: - Reading

/// A single now-playing snapshot. `elapsed` is the position (seconds) into the
/// track *at* `timestamp`; the widget advances it live between pushes.
public struct NowPlaying: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var isPlaying: Bool
    public var elapsed: TimeInterval?
    public var duration: TimeInterval?
    public var timestamp: Date

    public init(
        title: String,
        artist: String? = nil,
        album: String? = nil,
        isPlaying: Bool = true,
        elapsed: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        timestamp: Date
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.elapsed = elapsed
        self.duration = duration
        self.timestamp = timestamp
    }
}

// MARK: - Service contract

/// Source of now-playing data. The concrete implementation is deliberately
/// swappable: a simulated source for development, and a push source fed by an
/// external producer reading the HomePod / Apple Music / system MediaRemote.
public protocol MusicService: AnyObject {
    func nowPlaying() -> NowPlaying?      // nil = nothing playing
}

public enum MusicServiceKeys {
    public static let nowPlaying = ServiceKey<any MusicService>("nowPlaying")
}

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

// MARK: - Simulated source (dev only)

/// Development-only source: cycles a small fake playlist and advances the
/// current track's position over time, so the dev renderer shows a plausibly
/// playing tile with no producer wired up.
public final class SimulatedMusicService: MusicService {
    private struct Track {
        var title: String
        var artist: String
        var album: String
        var duration: TimeInterval
    }

    private static let playlist: [Track] = [
        Track(title: "Nightcall", artist: "Kavinsky", album: "OutRun", duration: 258),
        Track(title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", duration: 240),
        Track(title: "Digital Love", artist: "Daft Punk", album: "Discovery", duration: 301)
    ]

    private let startDate: Date
    private let now: () -> Date

    public init(
        startDate: Date = Date(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.startDate = startDate
        self.now = now
    }

    public func nowPlaying() -> NowPlaying? {
        let date = now()
        let elapsedTotal = max(0, date.timeIntervalSince(startDate))

        // Walk the playlist on a loop, using each track's real duration.
        let loopLength = Self.playlist.reduce(0) { $0 + $1.duration }
        var offset = elapsedTotal.truncatingRemainder(dividingBy: loopLength)
        for track in Self.playlist {
            if offset < track.duration {
                return NowPlaying(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    isPlaying: true,
                    elapsed: offset,
                    duration: track.duration,
                    timestamp: date
                )
            }
            offset -= track.duration
        }

        // Unreachable (offset is always < loopLength), but keep total.
        return nil
    }
}
