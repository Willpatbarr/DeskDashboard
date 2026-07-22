import DashboardKit
import Foundation

// Indoor Temperature — the TRANSFORM layer of the pipeline. Turns a raw
// `TemperatureReading` into display-ready strings (unit conversion, humidity,
// staleness). Owned privately by the widget (AD-003).
final class IndoorTemperatureWidgetModel: WidgetModel {
    /// A reading older than this is treated as stale (the remote producer went
    /// quiet). Indoor updates every 30s, so ~4 missed cycles.
    static let stalenessThreshold: TimeInterval = 150

    private let service: any IndoorTemperatureService
    private let displayOptions: IndoorTemperatureDisplayOptions

    private(set) var displayTemperature: String?
    private(set) var displayHumidity: String?
    private(set) var isStale: Bool = false

    init(
        service: any IndoorTemperatureService,
        displayOptions: IndoorTemperatureDisplayOptions
    ) {
        self.service = service
        self.displayOptions = displayOptions
    }

    // MARK: - WidgetModel lifecycle

    func activate() {
        refresh(at: Date())
    }

    func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        refresh(at: tick.date)
    }

    // MARK: - Formatting the reading

    func refresh(
        at date: Date
    ) {
        guard let reading = service.currentReading() else {
            displayTemperature = nil
            displayHumidity = nil
            isStale = false
            return
        }

        let degrees: Double
        let unitSymbol: String
        switch displayOptions.unit {
        case .celsius:
            degrees = reading.celsius
            unitSymbol = "C"
        case .fahrenheit:
            degrees = reading.celsius * 9 / 5 + 32
            unitSymbol = "F"
        }

        displayTemperature = "\(Int(degrees.rounded()))°\(unitSymbol)"

        if displayOptions.showsHumidity, let humidity = reading.humidity {
            displayHumidity = "\(Int(humidity.rounded()))% humidity"
        } else {
            displayHumidity = nil
        }

        isStale = date.timeIntervalSince(reading.timestamp) > Self.stalenessThreshold
    }
}
