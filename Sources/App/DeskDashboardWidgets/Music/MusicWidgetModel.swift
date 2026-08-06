// MusicWidgetModel.swift — Music TRANSFORM layer: formats track info, advances position.

import DashboardKit
import Foundation

// Music — the TRANSFORM layer of the pipeline. Turns a raw `NowPlaying` value
// into display-ready strings, advancing the track position live between pushes
// ("clock provides rhythm, model provides judgement", SDD §12). Owned privately
// by the widget (AD-003).
public final class MusicWidgetModel: WidgetModel {
    private let service: any MusicService
    private let displayOptions: MusicDisplayOptions

    private(set) var displayTitle: String?
    private(set) var displaySubtitle: String?
    private(set) var displayProgress: String?
    /// Track position as a fraction 0…1 (nil without both elapsed + duration).
    private(set) var progressFraction: Double?
    /// "2:20" — the live position alone, for a progress line's leading end.
    private(set) var displayElapsed: String?
    /// "4:18" — the track length alone, for a progress line's trailing end.
    private(set) var displayDuration: String?
    private(set) var isPlaying: Bool = false
    private(set) var hasTrack: Bool = false

    init(
        service: any MusicService,
        displayOptions: MusicDisplayOptions
    ) {
        self.service = service
        self.displayOptions = displayOptions
    }

    // MARK: - WidgetModel lifecycle

    public func activate() {
        refresh(at: Date())
    }

    public func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        refresh(at: tick.date)
    }

    // MARK: - Formatting the reading

    func refresh(
        at date: Date
    ) {
        guard let track = service.nowPlaying() else {
            displayTitle = nil
            displaySubtitle = nil
            displayProgress = nil
            progressFraction = nil
            displayElapsed = nil
            displayDuration = nil
            isPlaying = false
            hasTrack = false
            return
        }

        hasTrack = true
        isPlaying = track.isPlaying
        displayTitle = track.title
        displaySubtitle = subtitle(for: track)
        displayProgress = progress(for: track, at: date)
        progressFraction = fraction(for: track, at: date)
        displayElapsed = liveElapsed(for: track, at: date).map(timeText)
        displayDuration = track.duration.map(timeText)
    }

    // MARK: - Helpers

    /// "Artist" or "Artist · Album" (album only when present and enabled).
    private func subtitle(
        for track: NowPlaying
    ) -> String? {
        var parts: [String] = []
        if let artist = track.artist, !artist.isEmpty {
            parts.append(artist)
        }
        if displayOptions.showsAlbum, let album = track.album, !album.isEmpty {
            parts.append(album)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "1:23 / 3:45" (mm:ss), advancing elapsed live while playing. Returns nil
    /// when there's no position to show.
    private func progress(
        for track: NowPlaying,
        at date: Date
    ) -> String? {
        guard let live = liveElapsed(for: track, at: date) else { return nil }
        guard let duration = track.duration else {
            return timeText(live)
        }
        return "\(timeText(live)) / \(timeText(duration))"
    }

    /// Position ÷ duration, 0…1, advancing live like `progress`. Needs a
    /// duration; a stream with no known length has no fraction to report.
    private func fraction(
        for track: NowPlaying,
        at date: Date
    ) -> Double? {
        guard let live = liveElapsed(for: track, at: date),
              let duration = track.duration, duration > 0
        else { return nil }
        return min(1, live / duration)
    }

    /// The track position as of `date`. Advances only while playing (a paused
    /// track holds still), clamped to 0…duration. Nil when unreported.
    private func liveElapsed(
        for track: NowPlaying,
        at date: Date
    ) -> TimeInterval? {
        guard let elapsed = track.elapsed else { return nil }
        var live = elapsed
        if track.isPlaying {
            live += date.timeIntervalSince(track.timestamp)
        }
        live = max(0, live)
        if let duration = track.duration {
            live = min(live, duration)
        }
        return live
    }

    /// Seconds -> "m:ss" (or "h:mm:ss" for long tracks).
    private func timeText(
        _ interval: TimeInterval
    ) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
