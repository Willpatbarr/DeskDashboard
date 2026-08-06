// WidgetContent.swift — What a widget produces: values, progress, play state, metadata.

public protocol RenderableWidget: Widget {
    func render(environment: DashboardEnvironment) -> WidgetContent
}

public struct WidgetContent: Equatable, Sendable {
    public var title: String?
    public var primaryText: String
    public var secondaryText: String?
    public var accessoryText: String?
    /// How far along the widget's activity is, 0…1 — a track position, a timer,
    /// a download. Layouts that show a progress line read this; `nil` hides it.
    public var progress: Double?
    /// Short readout of the position along `progress` ("2:20"), shown at the
    /// leading end of a progress line.
    public var elapsedText: String?
    /// Short readout of the activity's full length ("4:18"), shown at the
    /// trailing end of a progress line.
    public var durationText: String?
    /// Whether the widget's activity is running (playing) or held (paused).
    /// Layouts that show a play/pause indicator read this; `nil` hides it.
    public var isPlaying: Bool?
    public var metadata: [WidgetContentMetadata]

    public init(
        title: String? = nil,
        primaryText: String,
        secondaryText: String? = nil,
        accessoryText: String? = nil,
        progress: Double? = nil,
        elapsedText: String? = nil,
        durationText: String? = nil,
        isPlaying: Bool? = nil,
        metadata: [WidgetContentMetadata] = []
    ) {
        self.title = title
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accessoryText = accessoryText
        self.progress = progress
        self.elapsedText = elapsedText
        self.durationText = durationText
        self.isPlaying = isPlaying
        self.metadata = metadata
    }
}

public struct WidgetContentMetadata: Equatable, Sendable {
    public var label: String
    public var value: String

    public init(
        label: String,
        value: String
    ) {
        self.label = label
        self.value = value
    }
}
