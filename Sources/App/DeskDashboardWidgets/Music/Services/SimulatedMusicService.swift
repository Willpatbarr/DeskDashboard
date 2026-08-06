// SimulatedMusicService.swift — Music source (dev): cycles a fake playlist over time.

import DashboardKit
import Foundation

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
