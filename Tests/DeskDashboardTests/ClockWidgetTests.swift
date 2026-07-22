import Foundation
import Testing
import DashboardKit
@testable import DeskDashboardWidgets

private let fixedDate = Date(timeIntervalSince1970: 1_752_598_845)

private func expectedTime(
    for date: Date,
    showsSeconds: Bool,
    timeZone: TimeZone = .current
) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = timeZone
    formatter.dateFormat = showsSeconds ? "h:mm:ss a" : "h:mm a"
    return formatter.string(from: date)
}

private func expectedDate(
    for date: Date,
    timeZone: TimeZone = .current
) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = timeZone
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: date)
}

private func makeDashboard(
    currentDate: @escaping () -> Date = { fixedDate }
) -> Dashboard {
    Dashboard().service(
        StubClockService(currentDate: currentDate),
        for: ClockServiceKeys.clock
    )
}

@Test func clockWidgetIsInertBeforeAttach() {
    let widget = ClockWidget()

    #expect(widget.displayTime == nil)
    #expect(widget.displayDate == nil)
}

@Test func clockWidgetRendersFallbackBeforeAttach() {
    let widget = ClockWidget()
    let environment = DashboardEnvironment(
        dashboardID: DashboardID(),
        widgetID: WidgetID(),
        theme: DarkDeskTheme(),
        layout: GridLayout(),
        refreshRate: .seconds(1)
    )

    let content = widget.render(environment: environment)

    #expect(content.primaryText == "--:--")
}

@Test func clockWidgetRendersInjectedServiceTimeOnAttach() {
    var dashboard = makeDashboard()

    dashboard.add(ClockWidget().id("clock"))

    let content = dashboard.attachedWidgetSnapshots.first?.content
    #expect(content?.primaryText == expectedTime(for: fixedDate, showsSeconds: false))
    #expect(content?.secondaryText == expectedDate(for: fixedDate))
}

@Test func clockWidgetTickUpdatesDisplayedTime() {
    let clock = ManualDashboardClock()
    let runner = DashboardRunner(
        dashboard: makeDashboard(),
        clock: clock
    )

    runner.add(ClockWidget().id("clock"))
    runner.start()

    let tickDate = fixedDate.addingTimeInterval(120)
    clock.advance(to: tickDate)

    let content = runner.attachedWidgetSnapshots.first?.content
    #expect(content?.primaryText == expectedTime(for: tickDate, showsSeconds: false))
}

@Test func clockWidgetShowSecondsFormatsWithSeconds() {
    var dashboard = makeDashboard()

    dashboard.add(ClockWidget().id("clock").showSeconds())

    let content = dashboard.attachedWidgetSnapshots.first?.content
    #expect(content?.primaryText == expectedTime(for: fixedDate, showsSeconds: true))
}

@Test func clockWidgetHideDateRemovesSecondaryText() {
    var dashboard = makeDashboard()

    dashboard.add(ClockWidget().id("clock").hideDate())

    let content = dashboard.attachedWidgetSnapshots.first?.content
    #expect(content?.secondaryText == nil)
}

@Test func clockWidgetTimeZoneModifierAppliesIdentifier() throws {
    let identifier = "America/New_York"
    let timeZone = try #require(TimeZone(identifier: identifier))
    var dashboard = makeDashboard()

    dashboard.add(
        ClockWidget()
            .id("clock")
            .timeZone(identifier: identifier)
    )

    let content = dashboard.attachedWidgetSnapshots.first?.content
    #expect(
        content?.primaryText == expectedTime(
            for: fixedDate,
            showsSeconds: false,
            timeZone: timeZone
        )
    )
    #expect(
        content?.metadata.contains(
            WidgetContentMetadata(label: "Time Zone", value: identifier)
        ) == true
    )
}

@Test func clockWidgetInvalidTimeZoneIdentifierIsIgnored() {
    var dashboard = makeDashboard()

    dashboard.add(
        ClockWidget()
            .id("clock")
            .timeZone(identifier: "Not/AZone")
    )

    let content = dashboard.attachedWidgetSnapshots.first?.content
    #expect(
        content?.metadata.contains(
            WidgetContentMetadata(
                label: "Time Zone",
                value: TimeZone.current.identifier
            )
        ) == true
    )
}

@Test func clockWidgetFallsBackToSystemClockWithoutService() {
    var dashboard = Dashboard()

    let before = Date()
    dashboard.add(ClockWidget().id("clock"))
    let after = Date()

    let content = dashboard.attachedWidgetSnapshots.first?.content
    let candidates = Set(
        [before, after].map {
            expectedTime(for: $0, showsSeconds: false)
        }
    )
    let primaryText = content?.primaryText ?? ""
    #expect(candidates.contains(primaryText))
}
