import DashboardKit
import Foundation

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

public protocol AlarmService: DashboardService {
    func alarms() -> [Alarm]
}

public enum AlarmServiceKeys {
    public static let alarms = ServiceKey<AnyAlarmService>("alarms")
}

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
