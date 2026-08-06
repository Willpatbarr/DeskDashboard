// MusicService.swift — Music DATA layer scaffold: the now-playing type, service contract and service key.

import DashboardKit
import Foundation

// Music — the DATA layer of the widget's Service -> WidgetModel -> Widget
// pipeline. Several interchangeable sources conform to `MusicService`; the
// widget never cares which one. This mirrors IndoorTemperature: the true
// "now playing" reading arrives over a network protocol (pyatv / AppleScript /
// MediaRemote) from an external producer POSTing to /ingest/now-playing —
// nothing here imports any media framework, so it runs on any platform.
//
// This file is the scaffold: the reading, the protocol, and the service key.
// Each source lives in its own file under `Services/`.

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
