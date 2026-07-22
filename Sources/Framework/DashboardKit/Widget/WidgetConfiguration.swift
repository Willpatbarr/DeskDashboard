public struct WidgetConfiguration: Equatable, Sendable {
    public var preferredID: WidgetID?
    public var title: String?
    public var size: WidgetSize
    public var priority: WidgetPriority
    public var isHidden: Bool
    public var refreshRate: RefreshRate?
    /// Which prebuilt tile layout this widget renders with. Renderers that
    /// interpret `WidgetView` (currently the SwiftCrossUI UI) use this.
    public var layout: WidgetLayout

    public init(
        preferredID: WidgetID? = nil,
        title: String? = nil,
        size: WidgetSize = .automatic,
        priority: WidgetPriority = .normal,
        isHidden: Bool = false,
        refreshRate: RefreshRate? = nil,
        layout: WidgetLayout = .standard
    ) {
        self.preferredID = preferredID
        self.title = title
        self.size = size
        self.priority = priority
        self.isHidden = isHidden
        self.refreshRate = refreshRate
        self.layout = layout
    }
}
