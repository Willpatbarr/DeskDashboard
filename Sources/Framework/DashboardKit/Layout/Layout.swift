// Layout.swift — Layout contract: decides each widget's visibility and placement (with defaults).

public struct LayoutItem: Sendable {
    public let id: WidgetID
    public let configuration: WidgetConfiguration

    public init(
        id: WidgetID,
        configuration: WidgetConfiguration
    ) {
        self.id = id
        self.configuration = configuration
    }
}

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

    func placement(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration,
        at index: Int
    ) -> WidgetPlacement

    /// Computes placements for all widgets together, in dashboard order.
    /// Layouts that pack spatially (spans, occupancy) implement this;
    /// the default falls back to independent per-widget placement.
    func placements(
        for items: [LayoutItem]
    ) -> [WidgetID: WidgetPlacement]
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

    func placement(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration,
        at index: Int
    ) -> WidgetPlacement {
        placement(
            for: widgetID,
            configuration: configuration
        )
    }

    func placements(
        for items: [LayoutItem]
    ) -> [WidgetID: WidgetPlacement] {
        var placements: [WidgetID: WidgetPlacement] = [:]

        for (index, item) in items.enumerated() {
            placements[item.id] = placement(
                for: item.id,
                configuration: item.configuration,
                at: index
            )
        }

        return placements
    }
}
