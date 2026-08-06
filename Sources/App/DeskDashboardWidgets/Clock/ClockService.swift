// ClockService.swift — Clock DATA layer: the time-source contract plus the system clock implementation.

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
