//
//  DashboardEnvironment.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

public struct DashboardEnvironment {
    public let dashboardID: DashboardID
    public let widgetID: WidgetID
    public let theme: any Theme
    public let layout: any Layout
    public let refreshRate: RefreshRate
    public let values: [String: Any]

    public init(
        dashboardID: DashboardID,
        widgetID: WidgetID,
        theme: any Theme,
        layout: any Layout,
        refreshRate: RefreshRate,
        values: [String: Any] = [:]
    ) {
        self.dashboardID = dashboardID
        self.widgetID = widgetID
        self.theme = theme
        self.layout = layout
        self.refreshRate = refreshRate
        self.values = values
    }

    public func value<Value>(
        for key: EnvironmentKey<Value>
    ) -> Value? {
        values[key.name] as? Value
    }
}
