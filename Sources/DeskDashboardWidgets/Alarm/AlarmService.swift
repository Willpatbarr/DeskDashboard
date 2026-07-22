import DashboardKit
import Foundation

// Alarm — the DATA layer of the widget's Service -> WidgetModel -> Widget
// pipeline. Alarms are one-shot, Date-based; recurrence is deliberately
// deferred (SDD §5.2 "leave a TODO").

// MARK: - Alarm

/// A single one-shot alarm. `date` is the absolute fire time.
public struct Alarm: Equatable, Sendable {
    public var id: String
    public var label: String?
    public var date: Date
    public var isEnabled: Bool

    public init(
        id: String,
        label: String? = nil,
        date: Date,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.label = label
        self.date = date
        self.isEnabled = isEnabled
    }
}

// MARK: - Service contract

public protocol AlarmService: DashboardService {
    func alarms() -> [Alarm]
}

public enum AlarmServiceKeys {
    public static let alarms = ServiceKey<AnyAlarmService>("alarms")
}

// MARK: - Type-erased wrapper

public final class AnyAlarmService: AlarmService {
    private let alarmsProvider: () -> [Alarm]

    public init(
        _ service: any AlarmService
    ) {
        self.alarmsProvider = service.alarms
    }

    public init(
        alarms: @escaping () -> [Alarm]
    ) {
        self.alarmsProvider = alarms
    }

    public func alarms() -> [Alarm] {
        alarmsProvider()
    }
}

// MARK: - In-memory store

/// The MVP alarm store: holds alarms in memory (no persistence yet).
public final class LocalAlarmStore: AlarmService {
    private var storedAlarms: [Alarm]

    public init(
        alarms: [Alarm] = []
    ) {
        self.storedAlarms = alarms
    }

    public func alarms() -> [Alarm] {
        storedAlarms
    }

    public func add(
        _ alarm: Alarm
    ) {
        remove(id: alarm.id)
        storedAlarms.append(alarm)
    }

    public func remove(
        id: String
    ) {
        storedAlarms.removeAll { $0.id == id }
    }

    public func setEnabled(
        _ isEnabled: Bool,
        id: String
    ) {
        guard let index = storedAlarms.firstIndex(where: { $0.id == id }) else {
            return
        }

        storedAlarms[index].isEnabled = isEnabled
    }
}
