// OutdoorTemperatureService.swift — Outdoor temp DATA scaffold: reading type, contract, service key.

import DashboardKit
import Foundation

// Outdoor Temperature — the DATA layer of the widget's
// Service -> WidgetModel -> Widget pipeline. Unlike Indoor/Music (push), Outdoor
// is a *pull*: the service fetches a remote weather API and caches the latest
// conditions (SDD §16: "Remote weather API — clock tick every 10 min, if
// stale"). Nothing here is Apple-only — the fetching source is plain
// Foundation + URLSession, so it runs on the Pi/Linux too.
//
// This file is the scaffold: the reading, the protocol, and the service key.
// Each source lives in its own file under `Services/`.

// MARK: - Reading

/// A single outdoor conditions reading. Temperature is stored canonically in
/// Celsius; the widget converts for display.
public struct OutdoorConditions: Equatable, Sendable {
    public var celsius: Double
    public var condition: String?
    public var humidity: Double?
    public var timestamp: Date

    public init(
        celsius: Double,
        condition: String? = nil,
        humidity: Double? = nil,
        timestamp: Date
    ) {
        self.celsius = celsius
        self.condition = condition
        self.humidity = humidity
        self.timestamp = timestamp
    }
}

// MARK: - Service contract

/// Source of outdoor conditions. The concrete implementation is swappable: a
/// simulated source for development and an Open-Meteo client for production.
public protocol OutdoorTemperatureService: AnyObject {
    func currentConditions() -> OutdoorConditions?
}

public enum OutdoorTemperatureServiceKeys {
    public static let outdoorTemperature = ServiceKey<any OutdoorTemperatureService>(
        "outdoorTemperature"
    )
}
