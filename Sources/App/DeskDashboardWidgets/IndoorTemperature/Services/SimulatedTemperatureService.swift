// SimulatedTemperatureService.swift — Indoor temp source (dev): sine-wave drift for the dev renderer.

import DashboardKit
import Foundation

// MARK: - Simulated source (dev only)

/// Development-only source: gentle sine-wave drift around a base temperature so
/// the dev renderer shows a plausibly changing reading with no hardware.
public final class SimulatedTemperatureService: IndoorTemperatureService {
    private let baseCelsius: Double
    private let amplitude: Double
    private let baseHumidity: Double
    private let startDate: Date
    private let now: () -> Date

    public init(
        baseCelsius: Double = 21.5,
        amplitude: Double = 1.2,
        baseHumidity: Double = 44,
        startDate: Date = Date(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.baseCelsius = baseCelsius
        self.amplitude = amplitude
        self.baseHumidity = baseHumidity
        self.startDate = startDate
        self.now = now
    }

    public func currentReading() -> TemperatureReading? {
        let date = now()
        let elapsed = date.timeIntervalSince(startDate)
        let phase = elapsed / 90
        let celsius = baseCelsius + amplitude * sin(phase)
        let humidity = baseHumidity + 3 * sin(phase / 2)

        return TemperatureReading(
            celsius: celsius,
            humidity: humidity,
            timestamp: date
        )
    }
}
