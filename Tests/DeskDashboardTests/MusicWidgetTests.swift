import Foundation
import Testing
import DashboardKit
@testable import DeskDashboardWidgets

private let baseDate = Date(timeIntervalSince1970: 1_752_600_000)

private func makeDashboard(
    nowPlaying: NowPlaying?
) -> Dashboard {
    Dashboard().service(
        AnyMusicService(nowPlaying: { nowPlaying }),
        for: MusicServiceKeys.nowPlaying
    )
}

private func snapshotContent(
    nowPlaying: NowPlaying?,
    widget: MusicWidget = MusicWidget(),
    tickAt tickDate: Date = baseDate
) -> WidgetContent? {
    var dashboard = makeDashboard(nowPlaying: nowPlaying)
    dashboard.add(widget.id("music"))
    dashboard.tick(at: tickDate)
    return dashboard.attachedWidgetSnapshots.first?.content
}

// MARK: - Inert / empty

@Test func musicIsInertBeforeAttach() {
    let widget = MusicWidget()

    #expect(widget.displayTitle == nil)
    #expect(widget.displaySubtitle == nil)
    #expect(!widget.isPlaying)
    #expect(!widget.hasTrack)
}

@Test func musicRendersNothingPlayingWithoutData() {
    let content = snapshotContent(nowPlaying: nil)

    #expect(content?.primaryText == "Nothing playing")
    #expect(content?.secondaryText == nil)
    #expect(content?.accessoryText == nil)
    #expect(content?.metadata.isEmpty == true)
}

// MARK: - Formatting

@Test func musicRendersTitleArtistAlbum() {
    let track = NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        album: "OutRun",
        isPlaying: true,
        elapsed: 83,
        duration: 258,
        timestamp: baseDate
    )
    let content = snapshotContent(nowPlaying: track)

    #expect(content?.primaryText == "Nightcall")
    #expect(content?.secondaryText == "Kavinsky · OutRun")
    #expect(content?.accessoryText == nil)
}

@Test func musicHidesAlbumWhenDisabled() {
    let track = NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        album: "OutRun",
        timestamp: baseDate
    )
    let content = snapshotContent(
        nowPlaying: track,
        widget: MusicWidget().showAlbum(false)
    )

    #expect(content?.secondaryText == "Kavinsky")
}

@Test func musicFallsBackToProgressWhenNoArtist() {
    let track = NowPlaying(
        title: "Untitled",
        artist: nil,
        album: nil,
        isPlaying: true,
        elapsed: 83,
        duration: 225,
        timestamp: baseDate
    )
    let content = snapshotContent(nowPlaying: track)

    // No artist/album line -> secondary text shows the progress string.
    #expect(content?.secondaryText == "1:23 / 3:45")
}

@Test func musicShowsPausedBadge() {
    let track = NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        isPlaying: false,
        elapsed: 10,
        duration: 258,
        timestamp: baseDate
    )
    let content = snapshotContent(nowPlaying: track)

    #expect(content?.accessoryText == "PAUSED")
}

@Test func musicPlayingHasNoBadge() {
    let track = NowPlaying(
        title: "Nightcall",
        isPlaying: true,
        timestamp: baseDate
    )
    let content = snapshotContent(nowPlaying: track)

    #expect(content?.accessoryText == nil)
}

// MARK: - Progress string

@Test func musicProgressMetadataFormatsMinutesSeconds() {
    let track = NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        elapsed: 83,
        duration: 225,
        timestamp: baseDate
    )
    let content = snapshotContent(nowPlaying: track)
    let progress = content?.metadata.first { $0.label == "Progress" }?.value

    #expect(progress == "1:23 / 3:45")
}

@Test func musicProgressClampsToDuration() {
    // Elapsed already at duration; a live-advance tick must not exceed it.
    let track = NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        isPlaying: true,
        elapsed: 225,
        duration: 225,
        timestamp: baseDate
    )
    let content = snapshotContent(
        nowPlaying: track,
        tickAt: baseDate.addingTimeInterval(30)
    )
    let progress = content?.metadata.first { $0.label == "Progress" }?.value

    #expect(progress == "3:45 / 3:45")
}

// MARK: - Live elapsed (hybrid tick)

@Test func musicElapsedAdvancesWhilePlaying() {
    let track = NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        isPlaying: true,
        elapsed: 60,
        duration: 258,
        timestamp: baseDate
    )
    let content = snapshotContent(
        nowPlaying: track,
        tickAt: baseDate.addingTimeInterval(15)
    )
    let progress = content?.metadata.first { $0.label == "Progress" }?.value

    // 60s + 15s tick = 75s = 1:15.
    #expect(progress == "1:15 / 4:18")
}

@Test func musicElapsedHoldsWhilePaused() {
    let track = NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        isPlaying: false,
        elapsed: 60,
        duration: 258,
        timestamp: baseDate
    )
    let content = snapshotContent(
        nowPlaying: track,
        tickAt: baseDate.addingTimeInterval(15)
    )
    let progress = content?.metadata.first { $0.label == "Progress" }?.value

    // Paused: position holds at 1:00 regardless of the 15s tick gap.
    #expect(progress == "1:00 / 4:18")
}

// MARK: - Push service + hybrid tick reflecting a mid-cycle push

@Test func pushMusicServiceUpdatesAndReads() {
    let store = PushMusicService()
    #expect(store.nowPlaying() == nil)

    let track = NowPlaying(title: "Nightcall", timestamp: baseDate)
    store.update(track)
    #expect(store.nowPlaying() == track)

    store.update(nil)
    #expect(store.nowPlaying() == nil)
}

@Test func musicHybridTickReflectsMidCyclePush() {
    let clock = ManualDashboardClock()
    let store = PushMusicService()
    let dashboard = Dashboard().service(
        AnyMusicService(store),
        for: MusicServiceKeys.nowPlaying
    )
    let runner = DashboardRunner(dashboard: dashboard, clock: clock)
    runner.add(MusicWidget().id("music"))
    runner.start()

    clock.advance(to: baseDate)
    // Nothing playing yet.
    #expect(runner.attachedWidgetSnapshots.first?.content?.primaryText == "Nothing playing")

    // A push arrives; the 1s tick re-reads the store on the next tick.
    store.update(
        NowPlaying(title: "Midnight City", artist: "M83", timestamp: baseDate)
    )
    clock.advance(to: baseDate.addingTimeInterval(1))
    #expect(runner.attachedWidgetSnapshots.first?.content?.primaryText == "Midnight City")
}

// MARK: - Simulated source

@Test func simulatedMusicServiceReportsFirstTrackAtStart() {
    let service = SimulatedMusicService(startDate: baseDate, now: { baseDate })
    let track = service.nowPlaying()

    #expect(track?.title == "Nightcall")
    #expect(track?.isPlaying == true)
    #expect(track?.elapsed == 0)
}
