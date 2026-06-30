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

    var attachedWidgetCount: Int {
        attachedWidgets.count
    }
}

// MARK: - Lifecycle

extension Dashboard {
    public mutating func add<W: Widget>(_ widget: W) {
        
        //param setup
        let widgetID = widget.configuration.id ?? WidgetID()
        let environment = makeEnvironment(
            for: widgetID,
            configuration: widget.configuration,
        )
        let model = widget.makeModel(environment: environment)
        let placement = configuration.layout.placement(
            for: widgetID,
            configuration: widget.configuration
        )

        let replacedWidget = attachedWidgets.updateValue(
            AttachedWidget(
                id: widgetID,
                configuration: widget.configuration,
                model: model,
                visibility: placement.visibility,
                placement: placement,
            ),
            forKey: widgetID
        )

        replacedWidget?.model.deactivate()
        model.activate()
    }

    public mutating func remove(widget id: WidgetID) {
        guard let attachedWidget = attachedWidgets.removeValue(forKey: id) else {
            return
        }
        
        attachedWidget.model.deactivate()
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
            values: configuration.environmentValues
        )
    }

    mutating func updateAttachedWidgetEnvironments() {
        for attachedWidget in attachedWidgets.values {
            let environment = makeEnvironment(
                for: attachedWidget.id,
                configuration: attachedWidget.configuration
            )

            attachedWidget.model.update(environment: environment)
        }
    }
}

// MARK: - Live Configuration

extension Dashboard {
    public mutating func applyTheme(_ theme: any Theme) {
        configuration.theme = theme
        updateAttachedWidgetEnvironments()
    }

    public mutating func applyRefreshRate(_ refreshRate: RefreshRate) {
        configuration.refreshRate = refreshRate
        updateAttachedWidgetEnvironments()
    }

    public mutating func applyLayout(_ layout: any Layout) {
        configuration.layout = layout
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
}

// MARK: - Visibility

extension Dashboard {
    func visibility(for widgetID: WidgetID) -> WidgetVisibility? {
        attachedWidgets[widgetID]?.visibility
    }

    mutating func setVisibility(
        _ visibility: WidgetVisibility,
        for widgetID: WidgetID
    ) {
        attachedWidgets[widgetID]?.visibility = visibility
    }
}

// MARK: - Placement

extension Dashboard {
    func placement(
        for widgetID: WidgetID
    ) -> WidgetPlacement? {
        attachedWidgets[widgetID]?.placement
    }
    
    mutating func updateAttachedWidgetPlacements() {
        for attachedWidget in attachedWidgets.values {
            let placement = configuration.layout.placement(
                for: attachedWidget.id,
                configuration: attachedWidget.configuration,
            )
            
            attachedWidgets[attachedWidget.id]?.placement = placement
            attachedWidgets[attachedWidget.id]?.visibility = placement.visibility
        }
    }
}
