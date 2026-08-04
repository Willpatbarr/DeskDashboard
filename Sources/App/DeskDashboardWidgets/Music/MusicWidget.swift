import DashboardKit
import Foundation

// Music — the DISPLAY layer of the pipeline. An inert tile until attached;
// activates its private model on attach, ticks it every second (the hybrid
// strategy, SDD §12: the 1s tick re-reads the push store so a new push shows
// within ~1s *and* the track position advances smoothly), and renders the
// model's state into WidgetContent.

// MARK: - Widget

public struct MusicWidget: ServiceBackedWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: MusicDisplayOptions
    public var boundService: (any MusicService)?
    public var model: MusicWidgetModel?

    public init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Music",
            size: .medium,
            refreshRate: .seconds(1)
        ),
        displayOptions: MusicDisplayOptions = MusicDisplayOptions()
    ) {
        self.configuration = configuration
        self.displayOptions = displayOptions
    }

    var displayTitle: String? {
        model?.displayTitle
    }

    var displaySubtitle: String? {
        model?.displaySubtitle
    }

    var displayProgress: String? {
        model?.displayProgress
    }

    var isPlaying: Bool {
        model?.isPlaying ?? false
    }

    var hasTrack: Bool {
        model?.hasTrack ?? false
    }

    // MARK: - Service-backed lifecycle

    public var serviceKey: ServiceKey<any MusicService> { MusicServiceKeys.nowPlaying }

    public func makeModel(_ service: any MusicService) -> MusicWidgetModel {
        MusicWidgetModel(service: service, displayOptions: displayOptions)
    }

    public func makeFallbackService() -> any MusicService {
        SimulatedMusicService()
    }

    // MARK: - Rendering

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        guard hasTrack else {
            return WidgetContent(
                title: configuration.title,
                primaryText: "Nothing playing",
                secondaryText: nil,
                accessoryText: nil,
                metadata: []
            )
        }

        var metadata: [WidgetContentMetadata] = []
        if let source = displayOptions.source {
            metadata.append(WidgetContentMetadata(label: "Source", value: source))
        }
        if let progress = displayProgress {
            metadata.append(WidgetContentMetadata(label: "Progress", value: progress))
        }

        return WidgetContent(
            title: configuration.title,
            primaryText: displayTitle ?? "Nothing playing",
            // Prefer the artist/album line; fall back to the progress string
            // when the track carries no artist or album.
            secondaryText: displaySubtitle ?? displayProgress,
            accessoryText: isPlaying ? nil : "PAUSED",
            metadata: metadata
        )
    }
}

// MARK: - Display options

public struct MusicDisplayOptions {
    public var showsAlbum: Bool
    public var source: String?

    public init(
        showsAlbum: Bool = true,
        source: String? = nil
    ) {
        self.showsAlbum = showsAlbum
        self.source = source
    }
}

// MARK: - Modifiers (composition over configuration)

extension MusicWidget {
    public func showAlbum(
        _ isShown: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.showsAlbum = isShown
        return copy
    }

    public func source(
        _ source: String?
    ) -> Self {
        var copy = self
        copy.displayOptions.source = source
        return copy
    }
}
