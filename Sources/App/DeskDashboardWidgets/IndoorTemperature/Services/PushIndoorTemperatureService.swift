// PushIndoorTemperatureService.swift — Indoor temp source (production): latest reading pushed over HTTP.

import DashboardKit
import Foundation

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
