import DashboardKit
import Foundation

// Outdoor Temperature — the TRANSFORM layer of the pipeline. Turns a raw
// `OutdoorConditions` into display-ready strings (unit conversion, condition,
// staleness). Owned privately by the widget (AD-003).
final class OutdoorTemperatureWidgetModel: WidgetModel {
    /// A reading older than this is treated as stale (the weather fetch went
    /// quiet). Outdoor refreshes every ~10 min, so this is a few missed cycles.
    static let stalenessThreshold: TimeInterval = 1800

    private let service: any OutdoorTemperatureService
    private let displayOptions: OutdoorTemperatureDisplayOptions

    private(set) var displayTemperature: String?
    private(set) var displayCondition: String?
    private(set) var isStale: Bool = false

    init(
        service: any OutdoorTemperatureService,
        displayOptions: OutdoorTemperatureDisplayOptions
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
        guard let conditions = service.currentConditions() else {
            displayTemperature = nil
            displayCondition = nil
            isStale = false
            return
        }

        let degrees: Double
        let unitSymbol: String
        switch displayOptions.unit {
        case .celsius:
            degrees = conditions.celsius
            unitSymbol = "C"
        case .fahrenheit:
            degrees = conditions.celsius * 9 / 5 + 32
            unitSymbol = "F"
        }

        displayTemperature = "\(Int(degrees.rounded()))°\(unitSymbol)"

        if displayOptions.showsCondition, let condition = conditions.condition, !condition.isEmpty {
            displayCondition = condition
        } else {
            displayCondition = nil
        }

        isStale = date.timeIntervalSince(conditions.timestamp) > Self.stalenessThreshold
    }
}
