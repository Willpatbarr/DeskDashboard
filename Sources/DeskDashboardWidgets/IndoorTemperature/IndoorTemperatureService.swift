import DashboardKit
import Foundation

// Indoor Temperature — the DATA layer of the widget's
// Service -> WidgetModel -> Widget pipeline. Several interchangeable sources
// conform to `IndoorTemperatureService`; the widget never cares which one.

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
public protocol IndoorTemperatureService: DashboardService {
    func currentReading() -> TemperatureReading?
}

public enum IndoorTemperatureServiceKeys {
    public static let indoorTemperature = ServiceKey<AnyIndoorTemperatureService>(
        "indoorTemperature"
    )
}

// MARK: - Type-erased wrapper

public final class AnyIndoorTemperatureService: IndoorTemperatureService {
    private let readingProvider: () -> TemperatureReading?

    public init(
        _ service: any IndoorTemperatureService
    ) {
        self.readingProvider = service.currentReading
    }

    public init(
        currentReading: @escaping () -> TemperatureReading?
    ) {
        self.readingProvider = currentReading
    }

    public func currentReading() -> TemperatureReading? {
        readingProvider()
    }
}

// MARK: - Push source (production: fed by the /ingest endpoint)

/// Push-backed source: holds the most recent reading pushed in from outside
/// (e.g. an Apple-side HomeKit producer POSTing the HomePod's value). Thread
/// safe — updates arrive on a server thread while the widget reads on main.
public final class PushIndoorTemperatureService: IndoorTemperatureService, @unchecked Sendable {
    private let lock = NSLock()
    private var latest: TemperatureReading?

    public init(
        initialReading: TemperatureReading? = nil
    ) {
        self.latest = initialReading
    }

    public func update(
        _ reading: TemperatureReading
    ) {
        lock.lock()
        latest = reading
        lock.unlock()
    }

    public func currentReading() -> TemperatureReading? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }
}

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
