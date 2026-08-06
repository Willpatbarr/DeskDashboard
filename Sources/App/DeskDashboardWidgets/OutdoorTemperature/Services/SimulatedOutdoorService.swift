// SimulatedOutdoorService.swift — Outdoor temp source (dev): sine-wave drift for the dev renderer.

import DashboardKit
import Foundation

// MARK: - Simulated source (dev only)

/// Development-only source: gentle sine-wave drift so the dev renderer shows a
/// plausibly changing reading with no network.
public final class SimulatedOutdoorService: OutdoorTemperatureService {
    private let baseCelsius: Double
    private let amplitude: Double
    private let condition: String
    private let startDate: Date
    private let now: () -> Date

    public init(
        baseCelsius: Double = 12,
        amplitude: Double = 6,
        condition: String = "Partly cloudy",
        startDate: Date = Date(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.baseCelsius = baseCelsius
        self.amplitude = amplitude
        self.condition = condition
        self.startDate = startDate
        self.now = now
    }

    public func currentConditions() -> OutdoorConditions? {
        let date = now()
        let elapsed = date.timeIntervalSince(startDate)
        let phase = elapsed / 3600
        let celsius = baseCelsius + amplitude * sin(phase)

        return OutdoorConditions(
            celsius: celsius,
            condition: condition,
            humidity: 55 + 10 * sin(phase / 2),
            timestamp: date
        )
    }
}
