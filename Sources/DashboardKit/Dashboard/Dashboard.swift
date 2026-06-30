//
//  Dashboard.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

public struct Dashboard {
    public var configuration: DashboardConfiguration
    private var attachedWidgets: [WidgetID: AttachedWidget]

    public init(
        configuration: DashboardConfiguration = DashboardConfiguration()
    ) {
        self.configuration = configuration
        self.attachedWidgets = [:]
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

    public func refreshRate(_ refreshRate: RefreshRate) -> Self {
        var copy = self
        copy.configuration.refreshRate = refreshRate
        return copy
    }
}

//lifecycle methods
extension Dashboard {
    public mutating func add<W: Widget>(_ widget: W) {
        
        //get the widget ID
        let widgetID = widget.configuration.id ?? WidgetID()
        
        //build the dashboard environment
        let environment = DashboardEnvironment(
            dashboardID: configuration.id,
            widgetID: widgetID,
            theme: configuration.theme,
            layout: configuration.layout,
            refreshRate: widget.configuration.refreshRate ?? configuration.refreshRate,
            values: configuration.environmentValues
        )
        
        //ask widget to make its own model
        let model = widget.makeModel(environment: environment)
        
        //store the model and widget in attached widget
        attachedWidgets[widgetID] = AttachedWidget(
            id: widgetID,
            configuration: widget.configuration,
            model: model
        )
        
        model.activate()
    }

    public mutating func remove(widget id: WidgetID) {
        guard let attachedWidget = attachedWidgets.removeValue(forKey: id) else {
            return
        }
        
        attachedWidget.model.deactivate()
    }
}

