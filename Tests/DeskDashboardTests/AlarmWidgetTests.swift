import Foundation
import Testing
import DashboardKit
@testable import DeskDashboardWidgets

private let baseDate = Date(timeIntervalSince1970: 1_752_600_000)

private func expectedAlarmTime(
    for date: Date,
    twentyFourHour: Bool = false,
    timeZone: TimeZone = .current
) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = timeZone
    formatter.dateFormat = twentyFourHour ? "H:mm" : "h:mm a"
    return formatter.string(from: date)
}

private func makeDashboard(
    alarms: [Alarm]
) -> Dashboard {
    Dashboard().service(
        LocalAlarmStore(alarms: alarms),
        for: AlarmServiceKeys.alarms
    )
}

private func snapshotContent(
    alarms: [Alarm],
    widget: AlarmWidget = AlarmWidget(),
    tickAt tickDate: Date
) -> WidgetContent? {
    var dashboard = makeDashboard(alarms: alarms)
    dashboard.add(widget.id("alarm"))
    dashboard.tick(at: tickDate)
    return dashboard.attachedWidgetSnapshots.first?.content
}

@Test func alarmWidgetIsInertBeforeAttach() {
    let widget = AlarmWidget()

    #expect(widget.displayNextAlarm == nil)
    #expect(widget.displayCountdown == nil)
    #expect(!widget.isFiring)
}

@Test func alarmWidgetRendersNoAlarmsWithEmptyStore() {
    let content = snapshotContent(
        alarms: [],
        tickAt: baseDate
    )

    #expect(content?.primaryText == "No alarms")
    #expect(content?.secondaryText == nil)
    #expect(content?.accessoryText == nil)
}

@Test func alarmWidgetPicksSoonestEnabledAlarm() {
    let sooner = baseDate.addingTimeInterval(3_600)
    let later = baseDate.addingTimeInterval(7_200)
    let content = snapshotContent(
        alarms: [
            Alarm(id: "later", date: later),
            Alarm(id: "sooner", date: sooner),
        ],
        tickAt: baseDate
    )

    #expect(content?.primaryText == expectedAlarmTime(for: sooner))
}

@Test func alarmWidgetSkipsDisabledAlarms() {
    let disabled = baseDate.addingTimeInterval(1_800)
    let enabled = baseDate.addingTimeInterval(3_600)
    let content = snapshotContent(
        alarms: [
            Alarm(id: "disabled", date: disabled, isEnabled: false),
            Alarm(id: "enabled", date: enabled),
        ],
        tickAt: baseDate
    )

    #expect(content?.primaryText == expectedAlarmTime(for: enabled))
}

@Test func alarmWidgetSkipsPastAlarms() {
    let past = baseDate.addingTimeInterval(-3_600)
    let content = snapshotContent(
        alarms: [Alarm(id: "past", date: past)],
        tickAt: baseDate
    )

    #expect(content?.primaryText == "No alarms")
}

@Test func alarmWidgetFormatsCountdowns() {
    let hourScale = snapshotContent(
        alarms: [Alarm(id: "a", date: baseDate.addingTimeInterval(7_500))],
        tickAt: baseDate
    )
    #expect(hourScale?.secondaryText == "in 2h 05m")

    let minuteScale = snapshotContent(
        alarms: [Alarm(id: "a", date: baseDate.addingTimeInterval(90))],
        tickAt: baseDate
    )
    #expect(minuteScale?.secondaryText == "in 1m 30s")

    let secondScale = snapshotContent(
        alarms: [Alarm(id: "a", date: baseDate.addingTimeInterval(45))],
        tickAt: baseDate
    )
    #expect(secondScale?.secondaryText == "in 45s")
}

@Test func alarmWidgetFiresWithinWindow() {
    let content = snapshotContent(
        alarms: [Alarm(id: "a", label: "Wake up", date: baseDate)],
        tickAt: baseDate.addingTimeInterval(30)
    )

    #expect(content?.primaryText == expectedAlarmTime(for: baseDate))
    #expect(content?.secondaryText == "Ringing!")
    #expect(content?.accessoryText == "RINGING")
    #expect(
        content?.metadata.contains(
            WidgetContentMetadata(label: "Alarm", value: "Wake up")
        ) == true
    )
}

@Test func alarmWidgetStopsFiringAfterWindow() {
    let content = snapshotContent(
        alarms: [Alarm(id: "a", date: baseDate)],
        tickAt: baseDate.addingTimeInterval(
            AlarmWidgetModel.firingWindow + 1
        )
    )

    #expect(content?.primaryText == "No alarms")
    #expect(content?.accessoryText == nil)
}

@Test func alarmWidgetTickUpdatesCountdown() {
    let alarmDate = baseDate.addingTimeInterval(600)
    let clock = ManualDashboardClock()
    let runner = DashboardRunner(
        dashboard: makeDashboard(
            alarms: [Alarm(id: "a", date: alarmDate)]
        ),
        clock: clock
    )

    runner.add(AlarmWidget().id("alarm"))
    runner.start()

    clock.advance(to: baseDate)
    #expect(
        runner.attachedWidgetSnapshots.first?.content?.secondaryText == "in 10m 00s"
    )

    clock.advance(to: baseDate.addingTimeInterval(60))
    #expect(
        runner.attachedWidgetSnapshots.first?.content?.secondaryText == "in 9m 00s"
    )
}

@Test func alarmWidgetTwentyFourHourFormatsTime() {
    let alarmDate = baseDate.addingTimeInterval(3_600)
    let content = snapshotContent(
        alarms: [Alarm(id: "a", date: alarmDate)],
        widget: AlarmWidget().twentyFourHour(),
        tickAt: baseDate
    )

    #expect(
        content?.primaryText == expectedAlarmTime(
            for: alarmDate,
            twentyFourHour: true
        )
    )
}

@Test func localAlarmStoreManagesAlarms() {
    let store = LocalAlarmStore()
    let alarm = Alarm(id: "a", date: baseDate)

    store.add(alarm)
    #expect(store.alarms() == [alarm])

    store.add(Alarm(id: "a", date: baseDate.addingTimeInterval(60)))
    #expect(store.alarms().count == 1)
    #expect(store.alarms().first?.date == baseDate.addingTimeInterval(60))

    store.setEnabled(false, id: "a")
    #expect(store.alarms().first?.isEnabled == false)

    store.setEnabled(true, id: "missing")
    #expect(store.alarms().count == 1)

    store.remove(id: "a")
    #expect(store.alarms().isEmpty)
}
