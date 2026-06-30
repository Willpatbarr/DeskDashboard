public struct WidgetConfiguration: Equatable, Sendable {
    public var id: WidgetID?
    public var title: String?
    public var size: WidgetSize
    public var priority: WidgetPriority
    public var isHidden: Bool
    public var refreshRate: RefreshRate?

    public init(
        id: WidgetID? = nil,
        title: String? = nil,
        size: WidgetSize = .automatic,
        priority: WidgetPriority = .normal,
        isHidden: Bool = false,
        refreshRate: RefreshRate? = nil
    ) {
        self.id = id
        self.title = title
        self.size = size
        self.priority = priority
        self.isHidden = isHidden
        self.refreshRate = refreshRate
    }
}
