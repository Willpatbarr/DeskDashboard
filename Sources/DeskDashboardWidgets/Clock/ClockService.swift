import DashboardKit
import Foundation

public protocol ClockService: DashboardService {
    func currentDate() -> Date
}

public enum ClockServiceKeys {
    public static let clock = ServiceKey<AnyClockService>("clock")
}

public final class AnyClockService: ClockService {
    private let currentDateProvider: () -> Date

    public init(
        _ service: any ClockService
    ) {
        self.currentDateProvider = service.currentDate
    }

    public init(
        currentDate: @escaping () -> Date
    ) {
        self.currentDateProvider = currentDate
    }

    public func currentDate() -> Date {
        currentDateProvider()
    }
}

public final class SystemClockService: ClockService {
    public init() {}

    public func currentDate() -> Date {
        Date()
    }
}
