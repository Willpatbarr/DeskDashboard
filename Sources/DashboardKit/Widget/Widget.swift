//
//  Widget.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

public protocol Widget {
    associatedtype Model: WidgetModel

    var configuration: WidgetConfiguration { get set }

    func makeModel(
        environment: DashboardEnvironment
    ) -> Model
}

public extension Widget {
    func id(_ id: WidgetID) -> Self {
        var copy = self
        copy.configuration.id = id
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
}
