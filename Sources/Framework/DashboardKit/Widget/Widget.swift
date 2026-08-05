//
//  Widget.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

public protocol Widget {
    var configuration: WidgetConfiguration { get set }

    mutating func attach(environment: DashboardEnvironment)
    mutating func update(environment: DashboardEnvironment)
    mutating func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    )
    mutating func detach()
}

public extension Widget {
    mutating func attach(environment: DashboardEnvironment) {}
    mutating func update(environment: DashboardEnvironment) {}
    mutating func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {}
    mutating func detach() {}
}

public extension Widget {
    func id(_ id: WidgetID) -> Self {
        var copy = self
        copy.configuration.preferredID = id
        return copy
    }

    func id(_ rawValue: String) -> Self {
        id(WidgetID(rawValue))
    }

    func title(_ title: String) -> Self {
        var copy = self
        copy.configuration.title = title
        return copy
    }

    func size(_ size: WidgetSize) -> Self {
        var copy = self
        copy.configuration.size = size
        return copy
    }

    func priority(_ priority: WidgetPriority) -> Self {
        var copy = self
        copy.configuration.priority = priority
        return copy
    }

    func hidden(_ isHidden: Bool = true) -> Self {
        var copy = self
        copy.configuration.isHidden = isHidden
        return copy
    }

    func refreshRate(_ refreshRate: RefreshRate) -> Self {
        var copy = self
        copy.configuration.refreshRate = refreshRate
        return copy
    }

    /// Chooses the prebuilt tile layout this widget renders with (default
    /// `.standard`). Swappable per widget: `ClockWidget().layout(.bigNumber)`.
    func layout(_ layout: WidgetLayout) -> Self {
        var copy = self
        copy.configuration.layout = layout
        return copy
    }

    /// Renders the widget without its tile chrome (surface, border, corners) —
    /// visually just the label and info sitting directly on the background.
    func containerless(_ isContainerless: Bool = true) -> Self {
        var copy = self
        copy.configuration.isContainerless = isContainerless
        return copy
    }
}
