import DashboardKit
import Foundation

protocol ClockService: DashboardService {
    func currentDate() -> Date
}

enum ClockServiceKeys {
    static let clock = ServiceKey<AnyClockService>("clock")
}

final class AnyClockService: ClockService {
    private let currentDateProvider: () -> Date

    init(
        _ service: any ClockService
    ) {
        self.currentDateProvider = service.currentDate
    }

    init(
        currentDate: @escaping () -> Date
    ) {
        self.currentDateProvider = currentDate
    }

    func currentDate() -> Date {
        currentDateProvider()
    }
}

final class SystemClockService: ClockService {
    init() {}

    func currentDate() -> Date {
        Date()
    }
}
