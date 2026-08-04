public protocol RenderableWidget: Widget {
    func render(environment: DashboardEnvironment) -> WidgetContent
}

public struct WidgetContent: Equatable, Sendable {
    public var title: String?
    public var primaryText: String
    public var secondaryText: String?
    public var accessoryText: String?
    public var metadata: [WidgetContentMetadata]

    public init(
        title: String? = nil,
        primaryText: String,
        secondaryText: String? = nil,
        accessoryText: String? = nil,
        metadata: [WidgetContentMetadata] = []
    ) {
        self.title = title
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accessoryText = accessoryText
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
