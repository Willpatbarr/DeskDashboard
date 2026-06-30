public protocol Layout: Sendable {
    var name: String { get }
    
    func visibility(
        for widget: WidgetID,
        configuration: WidgetConfiguration,
    ) -> WidgetVisibility
    
    func placement(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration
    ) -> WidgetPlacement
}

public extension Layout {
    
    func visibility(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration,
    ) -> WidgetVisibility {
        configuration.isHidden ? .hidden : .visible
    }
    
    func placement(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration
    ) -> WidgetPlacement {
        WidgetPlacement(
            visibility: visibility(
                for: widgetID,
                configuration: configuration,
            ),
        )
    }
}
