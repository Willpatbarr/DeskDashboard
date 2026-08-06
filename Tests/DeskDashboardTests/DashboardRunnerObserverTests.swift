// DashboardRunnerObserverTests.swift — Tests: the runner ticks widgets and notifies observers.

import Foundation
import Testing
import DeskDashboardWidgets
@testable import DashboardKit

@Test func runnerStartNotifiesObserverOnEachTick() {
    let clock = ManualDashboardClock()
    let runner = DashboardRunner(
        dashboard: Dashboard(),
        clock: clock
    )
    var observedDates: [Date] = []

    runner.start { tick in
        observedDates.append(tick.date)
    }

    let firstDate = Date(timeIntervalSince1970: 100)
    let secondDate = Date(timeIntervalSince1970: 101)
    clock.advance(to: firstDate)
    clock.advance(to: secondDate)

    #expect(observedDates == [firstDate, secondDate])
}

@Test func runnerObserverFiresAfterDashboardTickApplies() {
    let fixedDate = Date(timeIntervalSince1970: 1_752_598_845)
    let clock = ManualDashboardClock()
    let dashboard = Dashboard().service(
        StubClockService(currentDate: { fixedDate }),
        for: ClockServiceKeys.clock
    )
    let runner = DashboardRunner(
        dashboard: dashboard,
        clock: clock
    )
    runner.add(ClockWidget().id("clock").showSeconds())

    let tickDate = fixedDate.addingTimeInterval(60)
    var observedText: String?
    runner.start { _ in
        observedText = runner.attachedWidgetSnapshots.first?.content?.primaryText
    }

    clock.advance(to: tickDate)

    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = .current
    formatter.dateFormat = "h:mm:ss a"
    #expect(observedText == formatter.string(from: tickDate))
}

@Test func runnerStopHaltsObserverNotifications() {
    let clock = ManualDashboardClock()
    let runner = DashboardRunner(
        dashboard: Dashboard(),
        clock: clock
    )
    var tickCount = 0

    runner.start { _ in
        tickCount += 1
    }
    clock.advance(to: Date(timeIntervalSince1970: 100))
    runner.stop()
    clock.advance(to: Date(timeIntervalSince1970: 101))

    #expect(tickCount == 1)
}
