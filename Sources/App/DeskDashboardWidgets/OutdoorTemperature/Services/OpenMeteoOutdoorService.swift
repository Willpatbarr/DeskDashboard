// OpenMeteoOutdoorService.swift — Outdoor temp source (production): fetches conditions from Open-Meteo.

import DashboardKit
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
