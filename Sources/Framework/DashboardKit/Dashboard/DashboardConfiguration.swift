// DashboardConfiguration.swift — A dashboard's settings: id, theme, layout, refresh, services.

public struct DashboardConfiguration {
    public var id: DashboardID
    public var theme: any Theme
    public var layout: any Layout
    public var isLayoutPinned: Bool
    public var refreshRate: RefreshRate
    public var environmentValues: [String: Any]
    public var services: [String: Any]

    public init(
        id: DashboardID = DashboardID(),
        theme: any Theme = DarkDeskTheme(),
        layout: (any Layout)? = nil,
        isLayoutPinned: Bool = false,
        refreshRate: RefreshRate = .seconds(1),
        environmentValues: [String: Any] = [:],
        services: [String: Any] = [:]
    ) {
        self.id = id
        self.theme = theme
        self.layout = layout ?? theme.defaultLayout
        self.isLayoutPinned = isLayoutPinned
        self.refreshRate = refreshRate
        self.environmentValues = environmentValues
        self.services = services
    }
}
