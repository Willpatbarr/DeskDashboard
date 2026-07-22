import DashboardKit
import Foundation

public protocol ClockService: AnyObject {
    func currentDate() -> Date
}

public enum ClockServiceKeys {
    public static let clock = ServiceKey<any ClockService>("clock")
}

public final class SystemClockService: ClockService {
    public init() {}

    public func currentDate() -> Date {
        Date()
    }
}
