import DashboardKit
import Foundation

// Outdoor Temperature — the DISPLAY layer of the pipeline. An inert tile until
// attached; activates its private model on attach, ticks it every 15s, and
// renders the model's state into WidgetContent. The 15s tick is only a display
// cadence — the underlying weather fetch is gated to every 10 min inside the
// service (SDD §16), so ticking faster just re-reads the cache and surfaces the
// first fetch (and later staleness) promptly instead of after a full 10 min.

// MARK: - Widget

public struct OutdoorTemperatureWidget: RenderableWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: OutdoorTemperatureDisplayOptions
    private var model: OutdoorTemperatureWidgetModel?
    private var sourceName: String?

    public init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Outdoor",
            size: .medium,
            refreshRate: .seconds(15)
        ),
        displayOptions: OutdoorTemperatureDisplayOptions = OutdoorTemperatureDisplayOptions()
    ) {
        self.configuration = configuration
        self.displayOptions = displayOptions
    }

    var displayTemperature: String? {
        model?.displayTemperature
    }

    var displayCondition: String? {
        model?.displayCondition
    }

    var isStale: Bool {
        model?.isStale ?? false
    }

    // MARK: - Lifecycle

    public mutating func attach(environment: DashboardEnvironment) {
        let service = environment.service(for: OutdoorTemperatureServiceKeys.outdoorTemperature)
            ?? SimulatedOutdoorService()
        let model = OutdoorTemperatureWidgetModel(
            service: service,
            displayOptions: displayOptions
        )

        model.activate()
        self.model = model
    }

    public mutating func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        model?.tick(
            tick,
            environment: environment
        )
    }

    public mutating func detach() {
        model = nil
    }

    // MARK: - Rendering

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        var metadata: [WidgetContentMetadata] = []
        if let sourceName {
            metadata.append(WidgetContentMetadata(label: "Location", value: sourceName))
        }

        return WidgetContent(
            title: configuration.title,
            primaryText: displayTemperature ?? "—",
            secondaryText: displayTemperature == nil ? "No data" : displayCondition,
            accessoryText: isStale ? "STALE" : nil,
            metadata: metadata
        )
    }
}

// MARK: - Display options

public struct OutdoorTemperatureDisplayOptions {
    public enum Unit {
        case celsius
        case fahrenheit
    }

    public var unit: Unit
    public var showsCondition: Bool

    public init(
        unit: Unit = .fahrenheit,
        showsCondition: Bool = true
    ) {
        self.unit = unit
        self.showsCondition = showsCondition
    }
}

// MARK: - Modifiers (composition over configuration)

extension OutdoorTemperatureWidget {
    public func fahrenheit(
        _ isOn: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.unit = isOn ? .fahrenheit : .celsius
        return copy
    }

    public func celsius(
        _ isOn: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.unit = isOn ? .celsius : .fahrenheit
        return copy
    }

    public func showCondition(
        _ isShown: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.showsCondition = isShown
        return copy
    }

    /// Label shown in the tile's metadata (e.g. the city name).
    public func location(
        _ name: String?
    ) -> Self {
        var copy = self
        copy.sourceName = name
        return copy
    }
}
