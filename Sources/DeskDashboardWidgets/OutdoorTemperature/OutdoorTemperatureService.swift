import DashboardKit
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Outdoor Temperature — the DATA layer of the widget's
// Service -> WidgetModel -> Widget pipeline. Unlike Indoor/Music (push), Outdoor
// is a *pull*: the service fetches a remote weather API and caches the latest
// conditions (SDD §16: "Remote weather API — clock tick every 10 min, if
// stale"). Nothing here is Apple-only — it's plain Foundation + URLSession, so
// it runs on the Pi/Linux too.

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

// MARK: - Open-Meteo source (production)

/// Pull-backed source. Reads current conditions from Open-Meteo (free, no API
/// key). Self-refreshing: a `currentConditions()` call kicks off a background
/// fetch when the cache is older than `refreshInterval`, otherwise it just
/// returns the cached value. Thread safe — the fetch lands on a URLSession
/// thread while the widget reads on main.
public final class OpenMeteoOutdoorService: OutdoorTemperatureService, @unchecked Sendable {
    /// A place to read weather for. Hardcoded to Rexburg for now, but overridable.
    public struct Location: Equatable, Sendable {
        public var latitude: Double
        public var longitude: Double
        public var name: String

        public init(latitude: Double, longitude: Double, name: String) {
            self.latitude = latitude
            self.longitude = longitude
            self.name = name
        }

        public static let rexburg = Location(
            latitude: 43.826,
            longitude: -111.7897,
            name: "Rexburg, ID"
        )
    }

    public let location: Location
    private let refreshInterval: TimeInterval
    private let session: URLSession
    private let now: () -> Date

    private let lock = NSLock()
    private var latest: OutdoorConditions?
    private var lastFetchStart: Date?
    private var isFetching = false

    public init(
        location: Location = .rexburg,
        refreshInterval: TimeInterval = 600,   // 10 min (SDD §16)
        session: URLSession = .shared,
        now: @escaping () -> Date = { Date() }
    ) {
        self.location = location
        self.refreshInterval = refreshInterval
        self.session = session
        self.now = now
        // Eager first fetch so the tile fills in shortly after launch rather
        // than waiting for the first stale-triggered refresh.
        refreshIfStale()
    }

    public func currentConditions() -> OutdoorConditions? {
        let value = beginFetchIfStale()
        return value
    }

    /// Returns the cached value and, as a side effect, starts a fetch when the
    /// cache is stale and none is already in flight.
    @discardableResult
    private func beginFetchIfStale() -> OutdoorConditions? {
        lock.lock()
        let value = latest
        let isStale = lastFetchStart.map { now().timeIntervalSince($0) >= refreshInterval } ?? true
        let shouldFetch = !isFetching && isStale
        if shouldFetch {
            isFetching = true
            lastFetchStart = now()
        }
        lock.unlock()

        if shouldFetch {
            startFetch()
        }
        return value
    }

    private func refreshIfStale() {
        beginFetchIfStale()
    }

    private func startFetch() {
        guard let url = makeURL() else {
            finishFetch(with: nil)
            return
        }

        let fetchDate = now()
        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            let conditions = data.flatMap {
                OpenMeteoOutdoorService.parse($0, timestamp: fetchDate)
            }
            self?.finishFetch(with: conditions)
        }
        task.resume()
    }

    private func finishFetch(with conditions: OutdoorConditions?) {
        lock.lock()
        isFetching = false
        if let conditions {
            latest = conditions
        }
        lock.unlock()
    }

    private func makeURL() -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]
        return components?.url
    }

    // MARK: Parsing (exposed for tests)

    private struct Response: Decodable {
        struct Current: Decodable {
            var temperature_2m: Double?
            var relative_humidity_2m: Double?
            var weather_code: Int?
        }
        var current: Current?
    }

    /// Decode an Open-Meteo response into an `OutdoorConditions`, or nil when the
    /// payload lacks a temperature.
    static func parse(
        _ data: Data,
        timestamp: Date
    ) -> OutdoorConditions? {
        guard
            let response = try? JSONDecoder().decode(Response.self, from: data),
            let celsius = response.current?.temperature_2m
        else {
            return nil
        }

        return OutdoorConditions(
            celsius: celsius,
            condition: response.current?.weather_code.map(conditionText(forWeatherCode:)),
            humidity: response.current?.relative_humidity_2m,
            timestamp: timestamp
        )
    }

    /// Map a WMO weather interpretation code to a short human label.
    static func conditionText(
        forWeatherCode code: Int
    ) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm w/ hail"
        default: return "—"
        }
    }
}

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
