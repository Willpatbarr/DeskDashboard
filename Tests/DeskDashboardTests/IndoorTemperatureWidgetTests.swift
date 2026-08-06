// IndoorTemperatureWidgetTests.swift — Tests: indoor temperature lifecycle, conversion and staleness.

import Foundation
import Testing
import DashboardKit
@testable import DeskDashboardWidgets

private let baseDate = Date(timeIntervalSince1970: 1_752_600_000)

private func makeDashboard(
    reading: TemperatureReading?
) -> Dashboard {
    Dashboard().service(
        StubIndoorTemperatureService(currentReading: { reading }),
        for: IndoorTemperatureServiceKeys.indoorTemperature
    )
}

private func snapshotContent(
    reading: TemperatureReading?,
    widget: IndoorTemperatureWidget = IndoorTemperatureWidget(),
    tickAt tickDate: Date = baseDate
) -> WidgetContent? {
    var dashboard = makeDashboard(reading: reading)
    dashboard.add(widget.id("indoor"))
    dashboard.tick(at: tickDate)
    return dashboard.attachedWidgetSnapshots.first?.content
}

@Test func indoorTemperatureIsInertBeforeAttach() {
    let widget = IndoorTemperatureWidget()

    #expect(widget.displayTemperature == nil)
    #expect(widget.displayHumidity == nil)
    #expect(!widget.isStale)
}

@Test func indoorTemperatureRendersDashWithoutReading() {
    let content = snapshotContent(reading: nil)

    #expect(content?.primaryText == "—")
    #expect(content?.secondaryText == "No sensor")
    #expect(content?.accessoryText == nil)
}

@Test func indoorTemperatureFormatsFahrenheitByDefault() {
    let reading = TemperatureReading(celsius: 22, humidity: 45, timestamp: baseDate)
    let content = snapshotContent(reading: reading)

    // 22°C -> 71.6°F -> rounds to 72
    #expect(content?.primaryText == "72°F")
    #expect(content?.secondaryText == "45% humidity")
}

@Test func indoorTemperatureCelsiusModifierFormatsCelsius() {
    let reading = TemperatureReading(celsius: 21.5, humidity: 40, timestamp: baseDate)
    let content = snapshotContent(
        reading: reading,
        widget: IndoorTemperatureWidget().celsius()
    )

    #expect(content?.primaryText == "22°C")
}

@Test func indoorTemperatureHideHumidityRemovesSecondaryText() {
    let reading = TemperatureReading(celsius: 20, humidity: 50, timestamp: baseDate)
    let content = snapshotContent(
        reading: reading,
        widget: IndoorTemperatureWidget().showHumidity(false)
    )

    #expect(content?.secondaryText == nil)
}

@Test func indoorTemperatureFlagsStaleReading() {
    let staleReading = TemperatureReading(
        celsius: 20,
        humidity: 50,
        timestamp: baseDate
    )
    let content = snapshotContent(
        reading: staleReading,
        tickAt: baseDate.addingTimeInterval(
            IndoorTemperatureWidgetModel.stalenessThreshold + 1
        )
    )

    #expect(content?.accessoryText == "STALE")
}

@Test func indoorTemperatureFreshReadingIsNotStale() {
    let reading = TemperatureReading(
        celsius: 20,
        humidity: 50,
        timestamp: baseDate
    )
    let content = snapshotContent(
        reading: reading,
        tickAt: baseDate.addingTimeInterval(30)
    )

    #expect(content?.accessoryText == nil)
}

@Test func indoorTemperatureUpdatesOnTickWithThrottledRefreshRate() {
    let clock = ManualDashboardClock()
    var celsius = 20.0
    var readingTimestamp = baseDate
    let dashboard = Dashboard().service(
        StubIndoorTemperatureService(currentReading: {
            TemperatureReading(celsius: celsius, humidity: 40, timestamp: readingTimestamp)
        }),
        for: IndoorTemperatureServiceKeys.indoorTemperature
    )
    let runner = DashboardRunner(dashboard: dashboard, clock: clock)
    runner.add(IndoorTemperatureWidget().id("indoor").celsius())
    runner.start()

    clock.advance(to: baseDate)
    #expect(runner.attachedWidgetSnapshots.first?.content?.primaryText == "20°C")

    // Within the 30s refresh window: throttled, no update delivered.
    celsius = 25
    readingTimestamp = baseDate.addingTimeInterval(10)
    clock.advance(to: baseDate.addingTimeInterval(10))
    #expect(runner.attachedWidgetSnapshots.first?.content?.primaryText == "20°C")

    // After the 30s window elapses: update delivered.
    readingTimestamp = baseDate.addingTimeInterval(30)
    clock.advance(to: baseDate.addingTimeInterval(30))
    #expect(runner.attachedWidgetSnapshots.first?.content?.primaryText == "25°C")
}

@Test func simulatedTemperatureServiceProducesReadingNearBase() {
    let service = SimulatedTemperatureService(
        baseCelsius: 21.5,
        amplitude: 1.2,
        startDate: baseDate,
        now: { baseDate }
    )

    let reading = service.currentReading()
    // At startDate the sine phase is 0, so the reading equals the base.
    #expect(reading?.celsius == 21.5)
}
