import DashboardKit
import Foundation

public struct IndoorTemperatureWidget: RenderableWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: IndoorTemperatureDisplayOptions
    private var model: IndoorTemperatureWidgetModel?

    public init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Indoor",
            size: .medium,
            refreshRate: .seconds(30)
        ),
        displayOptions: IndoorTemperatureDisplayOptions = IndoorTemperatureDisplayOptions()
    ) {
        self.configuration = configuration
        self.displayOptions = displayOptions
    }

    var displayTemperature: String? {
        model?.displayTemperature
    }

    var displayHumidity: String? {
        model?.displayHumidity
    }

    var isStale: Bool {
        model?.isStale ?? false
    }

    public mutating func attach(environment: DashboardEnvironment) {
        let service = environment.service(for: IndoorTemperatureServiceKeys.indoorTemperature)
            ?? AnyIndoorTemperatureService(SimulatedTemperatureService())
        let model = IndoorTemperatureWidgetModel(
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

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        WidgetContent(
            title: configuration.title,
            primaryText: displayTemperature ?? "—",
            secondaryText: displayTemperature == nil ? "No sensor" : displayHumidity,
            accessoryText: isStale ? "STALE" : nil,
            metadata: [
                WidgetContentMetadata(
                    label: "Source",
                    value: "HomePod"
                )
            ]
        )
    }
}

public struct IndoorTemperatureDisplayOptions {
    public enum Unit {
        case celsius
        case fahrenheit
    }

    public var unit: Unit
    public var showsHumidity: Bool

    public init(
        unit: Unit = .fahrenheit,
        showsHumidity: Bool = true
    ) {
        self.unit = unit
        self.showsHumidity = showsHumidity
    }
}

extension IndoorTemperatureWidget {
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

    public func showHumidity(
        _ isShown: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.showsHumidity = isShown
        return copy
    }
}
