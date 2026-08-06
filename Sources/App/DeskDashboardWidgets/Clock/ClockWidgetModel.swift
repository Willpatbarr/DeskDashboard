// ClockWidgetModel.swift — Clock TRANSFORM layer: formats the current time and date for display.

import DashboardKit
import Foundation

public final class ClockWidgetModel: WidgetModel {
    private let service: any ClockService
    private let formatter: DateFormatter
    private let displayOptions: ClockDisplayOptions

    private(set) var displayTime: String = ""
    private(set) var displayDate: String?

    init(
        service: any ClockService,
        displayOptions: ClockDisplayOptions,
        locale: Locale = .current,
        timeZone: TimeZone
    ) {
        self.service = service
        self.displayOptions = displayOptions
        self.formatter = DateFormatter()
        self.formatter.locale = locale
        self.formatter.timeZone = timeZone
    }

    public func activate() {
        refresh()
    }

    public func update(environment: DashboardEnvironment) {
        refresh()
    }

    public func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        refresh(at: tick.date)
    }

    func refresh() {
        refresh(at: service.currentDate())
    }

    private func refresh(
        at date: Date
    ) {
        formatter.dateFormat = displayOptions.showsSeconds ? "h:mm:ss a" : "h:mm a"
        displayTime = formatter.string(from: date)

        if displayOptions.showsDate {
            formatter.dateFormat = "EEEE, MMM d"
            displayDate = formatter.string(from: date)
        } else {
            displayDate = nil
        }
    }
}
