import DashboardKit
import Foundation

final class ClockWidgetModel: WidgetModel {
    private let service: any ClockService
    private let formatter: DateFormatter

    private(set) var displayTime: String = ""
    private(set) var displayDate: String = ""

    init(
        service: any ClockService,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) {
        self.service = service
        self.formatter = DateFormatter()
        self.formatter.locale = locale
        self.formatter.timeZone = timeZone
    }

    func activate() {
        refresh()
    }

    func update(environment: DashboardEnvironment) {
        refresh()
    }

    func refresh() {
        let date = service.currentDate()

        formatter.dateFormat = "h:mm a"
        displayTime = formatter.string(from: date)

        formatter.dateFormat = "EEEE, MMM d"
        displayDate = formatter.string(from: date)
    }
}
