// IndoorTemperatureWidget.swift — Indoor temp DISPLAY layer: renders temperature and humidity.

import DashboardKit
import Foundation

// Indoor Temperature — the DISPLAY layer of the pipeline. An inert tile until
// attached; activates its private model on attach, ticks it (throttled to 30s
// by its refresh rate), and renders the model's state into WidgetContent.

// MARK: - Widget

public struct IndoorTemperatureWidget: ServiceBackedWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: IndoorTemperatureDisplayOptions
    public var boundService: (any IndoorTemperatureService)?
    public var model: IndoorTemperatureWidgetModel?

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

    // MARK: - Service-backed lifecycle

    public var serviceKey: ServiceKey<any IndoorTemperatureService> {
        IndoorTemperatureServiceKeys.indoorTemperature
    }

    public func makeModel(_ service: any IndoorTemperatureService) -> IndoorTemperatureWidgetModel {
        IndoorTemperatureWidgetModel(service: service, displayOptions: displayOptions)
    }

    public func makeFallbackService() -> any IndoorTemperatureService {
        SimulatedTemperatureService()
    }

    // MARK: - Rendering

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

// MARK: - Display options

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

// MARK: - Modifiers (composition over configuration)

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
