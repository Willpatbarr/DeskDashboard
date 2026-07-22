//
//  Dashboard.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

import Foundation

public struct Dashboard {
    public var configuration: DashboardConfiguration
    private var attachedWidgets: [WidgetID: AttachedWidget]
    private var widgetOrder: [WidgetID]

    public init(
        configuration: DashboardConfiguration = DashboardConfiguration()
    ) {
        self.configuration = configuration
        self.attachedWidgets = [:]
        self.widgetOrder = []
    }

    public func theme(_ theme: any Theme) -> Self {
        var copy = self
        copy.configuration.theme = theme

        if copy.configuration.isLayoutPinned == false {
            copy.configuration.layout = theme.defaultLayout
        }

        return copy
    }

    public func layout(_ layout: any Layout) -> Self {
        var copy = self
        copy.configuration.layout = layout
        copy.configuration.isLayoutPinned = true
        return copy
    }

    public func environment<Value>(
        _ value: Value,
        for key: EnvironmentKey<Value>
    ) -> Self {
        var copy = self
        copy.configuration.environmentValues[key.name] = value
        return copy
    }

    public func service<Service>(
        _ service: Service,
        for key: ServiceKey<Service>
    ) -> Self {
        var copy = self
        copy.configuration.services[key.name] = service
        return copy
    }

    public func refreshRate(_ refreshRate: RefreshRate) -> Self {
        var copy = self
        copy.configuration.refreshRate = refreshRate
        return copy
    }

    public var attachedWidgetCount: Int {
        attachedWidgets.count
    }

    public var attachedWidgetSnapshots: [AttachedWidgetSnapshot] {
        widgetOrder.compactMap { widgetID in
            guard let attachedWidget = attachedWidgets[widgetID] else {
                return nil
            }

            let environment = makeEnvironment(
                for: attachedWidget.id,
                configuration: attachedWidget.widget.configuration
            )

            return AttachedWidgetSnapshot(
                id: attachedWidget.id,
                configuration: attachedWidget.widget.configuration,
                placement: attachedWidget.placement,
                content: renderContent(
                    for: attachedWidget.widget,
                    environment: environment
                )
            )
        }
    }
}

// MARK: - Lifecycle

extension Dashboard {
    @discardableResult
    public mutating func add<W: Widget>(_ widget: W) -> WidgetID {
        var widget = widget
        let widgetID = resolveWidgetID(
            for: widget.configuration
        )
        let environment = makeEnvironment(
            for: widgetID,
            configuration: widget.configuration
        )

        if var replacedWidget = attachedWidgets.removeValue(forKey: widgetID) {
            replacedWidget.widget.detach()
        }

        widget.attach(environment: environment)

        if widgetOrder.contains(widgetID) == false {
            widgetOrder.append(widgetID)
        }

        attachedWidgets[widgetID] = AttachedWidget(
            id: widgetID,
            widget: widget,
            placement: WidgetPlacement(
                visibility: configuration.layout.visibility(
                    for: widgetID,
                    configuration: widget.configuration
                )
            ),
            lastTickDate: nil
        )

        updateAttachedWidgetPlacements()

        return widgetID
    }

    public mutating func remove(widget id: WidgetID) {
        guard var attachedWidget = attachedWidgets.removeValue(forKey: id) else {
            return
        }

        attachedWidget.widget.detach()
        widgetOrder.removeAll { $0 == id }
        updateAttachedWidgetPlacements()
    }
}

// MARK: - Ticks

extension Dashboard {
    public mutating func tick(
        at date: Date = Date()
    ) {
        let tick = DashboardTick(date: date)

        for widgetID in widgetOrder {
            guard var attachedWidget = attachedWidgets[widgetID] else {
                continue
            }

            guard shouldDeliver(
                tick,
                to: attachedWidget
            ) else {
                continue
            }

            let environment = makeEnvironment(
                for: attachedWidget.id,
                configuration: attachedWidget.widget.configuration
            )

            attachedWidget.widget.tick(
                tick,
                environment: environment
            )
            attachedWidget.lastTickDate = date
            attachedWidgets[widgetID] = attachedWidget
        }
    }

    func shouldDeliver(
        _ tick: DashboardTick,
        to attachedWidget: AttachedWidget
    ) -> Bool {
        guard attachedWidget.placement.visibility == .visible else {
            return false
        }

        guard let lastTickDate = attachedWidget.lastTickDate else {
            return true
        }

        let refreshRate = attachedWidget.widget.configuration.refreshRate
            ?? configuration.refreshRate

        return tick.date.timeIntervalSince(lastTickDate) >= refreshRate.seconds
    }
}

// MARK: - Identity

extension Dashboard {
    public var widgetIDs: [WidgetID] {
        widgetOrder
    }

    func resolveWidgetID(
        for widgetConfiguration: WidgetConfiguration
    ) -> WidgetID {
        widgetConfiguration.preferredID ?? WidgetID()
    }
}

// MARK: - Environment

extension Dashboard {
    func makeEnvironment(
        for widgetID: WidgetID,
        configuration widgetConfiguration: WidgetConfiguration,
    ) -> DashboardEnvironment {
        DashboardEnvironment(
            dashboardID: configuration.id,
            widgetID: widgetID,
            theme: configuration.theme,
            layout: configuration.layout,
            refreshRate: widgetConfiguration.refreshRate ?? configuration.refreshRate,
            values: configuration.environmentValues,
            services: configuration.services
        )
    }

    mutating func updateAttachedWidgetEnvironments() {
        for widgetID in widgetOrder {
            guard var attachedWidget = attachedWidgets[widgetID] else {
                continue
            }

            let environment = makeEnvironment(
                for: attachedWidget.id,
                configuration: attachedWidget.widget.configuration
            )

            attachedWidget.widget.update(environment: environment)
            attachedWidgets[widgetID] = attachedWidget
        }
    }

    func renderContent(
        for widget: any Widget,
        environment: DashboardEnvironment
    ) -> WidgetContent? {
        guard let renderableWidget = widget as? any RenderableWidget else {
            return nil
        }

        return renderableWidget.render(environment: environment)
    }
}

// MARK: - Live Configuration

extension Dashboard {
    public mutating func applyTheme(_ theme: any Theme) {
        configuration.theme = theme
        if configuration.isLayoutPinned == false {
            configuration.layout = theme.defaultLayout
            updateAttachedWidgetPlacements()
        }

        updateAttachedWidgetEnvironments()
    }

    public mutating func applyRefreshRate(_ refreshRate: RefreshRate) {
        configuration.refreshRate = refreshRate
        updateAttachedWidgetEnvironments()
    }

    public mutating func applyLayout(_ layout: any Layout) {
        configuration.layout = layout
        configuration.isLayoutPinned = true
        updateAttachedWidgetPlacements()
        updateAttachedWidgetEnvironments()
    }

    public mutating func applyEnvironment<Value>(
        _ value: Value,
        for key: EnvironmentKey<Value>
    ) {
        configuration.environmentValues[key.name] = value
        updateAttachedWidgetEnvironments()
    }

    public mutating func applyService<Service>(
        _ service: Service,
        for key: ServiceKey<Service>
    ) {
        configuration.services[key.name] = service
        updateAttachedWidgetEnvironments()
    }
}

// MARK: - Placement

extension Dashboard {
    public func placement(
        for widgetID: WidgetID
    ) -> WidgetPlacement? {
        attachedWidgets[widgetID]?.placement
    }
    
    mutating func updateAttachedWidgetPlacements() {
        let items = widgetOrder.compactMap { widgetID -> LayoutItem? in
            guard let attachedWidget = attachedWidgets[widgetID] else {
                return nil
            }

            return LayoutItem(
                id: widgetID,
                configuration: attachedWidget.widget.configuration
            )
        }

        let placements = configuration.layout.placements(for: items)

        for widgetID in widgetOrder {
            guard let placement = placements[widgetID] else {
                continue
            }

            attachedWidgets[widgetID]?.placement = placement
        }
    }
}
