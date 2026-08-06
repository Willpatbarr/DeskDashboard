// IndoorTemperatureService.swift — Indoor temp DATA scaffold: reading type, contract, service key.

import DashboardKit
import Foundation

// Indoor Temperature — the DATA layer of the widget's
// Service -> WidgetModel -> Widget pipeline. Several interchangeable sources
// conform to `IndoorTemperatureService`; the widget never cares which one.
//
// This file is the scaffold: the reading, the protocol, and the service key.
// Each source lives in its own file under `Services/`.

// MARK: - Reading

/// A single indoor climate reading. Temperature is stored canonically in
/// Celsius; the widget converts for display.
public struct TemperatureReading: Equatable, Sendable {
    public var celsius: Double
    public var humidity: Double?
    public var timestamp: Date

    public init(
        celsius: Double,
        humidity: Double? = nil,
        timestamp: Date
    ) {
        self.celsius = celsius
        self.humidity = humidity
        self.timestamp = timestamp
    }
}

// MARK: - Service contract

/// Source of indoor climate data. The concrete implementation is deliberately
/// swappable: a simulated source for development, and later a plain HTTP/file
/// client fed by an Apple-side HomeKit producer reading the HomePod. Nothing
/// here imports HomeKit, so the service runs on any platform (incl. the Pi).
public protocol IndoorTemperatureService: AnyObject {
    func currentReading() -> TemperatureReading?
}

public enum IndoorTemperatureServiceKeys {
    public static let indoorTemperature = ServiceKey<any IndoorTemperatureService>(
        "indoorTemperature"
    )
}
