import DashboardKit
import Foundation

// Music — the TRANSFORM layer of the pipeline. Turns a raw `NowPlaying` value
// into display-ready strings, advancing the track position live between pushes
// ("clock provides rhythm, model provides judgement", SDD §12). Owned privately
// by the widget (AD-003).
final class MusicWidgetModel: WidgetModel {
    private let service: any MusicService
    private let displayOptions: MusicDisplayOptions

    private(set) var displayTitle: String?
    private(set) var displaySubtitle: String?
    private(set) var displayProgress: String?
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

    func activate() {
        refresh(at: Date())
    }

    func tick(
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
            isPlaying = false
            hasTrack = false
            return
        }

        hasTrack = true
        isPlaying = track.isPlaying
        displayTitle = track.title
        displaySubtitle = subtitle(for: track)
        displayProgress = progress(for: track, at: date)
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
        guard let elapsed = track.elapsed else { return nil }

        // Advance the position only while playing; a paused track holds still.
        var live = elapsed
        if track.isPlaying {
            live += date.timeIntervalSince(track.timestamp)
        }
        live = max(0, live)
        if let duration = track.duration {
            live = min(live, duration)
        }

        guard let duration = track.duration else {
            return timeText(live)
        }
        return "\(timeText(live)) / \(timeText(duration))"
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
