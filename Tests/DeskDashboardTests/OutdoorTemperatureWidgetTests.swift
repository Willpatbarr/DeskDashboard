import Foundation
import Testing
import DashboardKit
@testable import DeskDashboardWidgets

private let baseDate = Date(timeIntervalSince1970: 1_752_600_000)

private func makeDashboard(
    conditions: OutdoorConditions?
) -> Dashboard {
    Dashboard().service(
        AnyOutdoorTemperatureService(currentConditions: { conditions }),
        for: OutdoorTemperatureServiceKeys.outdoorTemperature
    )
}

private func snapshotContent(
    conditions: OutdoorConditions?,
    widget: OutdoorTemperatureWidget = OutdoorTemperatureWidget(),
    tickAt tickDate: Date = baseDate
) -> WidgetContent? {
    var dashboard = makeDashboard(conditions: conditions)
    dashboard.add(widget.id("outdoor"))
    dashboard.tick(at: tickDate)
    return dashboard.attachedWidgetSnapshots.first?.content
}

// MARK: - Inert / empty

@Test func outdoorIsInertBeforeAttach() {
    let widget = OutdoorTemperatureWidget()

    #expect(widget.displayTemperature == nil)
    #expect(widget.displayCondition == nil)
    #expect(!widget.isStale)
}

@Test func outdoorRendersDashWithoutData() {
    let content = snapshotContent(conditions: nil)

    #expect(content?.primaryText == "—")
    #expect(content?.secondaryText == "No data")
    #expect(content?.accessoryText == nil)
}

// MARK: - Formatting

@Test func outdoorFormatsFahrenheitByDefault() {
    let conditions = OutdoorConditions(
        celsius: 22,
        condition: "Clear",
        humidity: 40,
        timestamp: baseDate
    )
    let content = snapshotContent(conditions: conditions)

    // 22°C -> 71.6°F -> rounds to 72
    #expect(content?.primaryText == "72°F")
    #expect(content?.secondaryText == "Clear")
}

@Test func outdoorCelsiusModifierFormatsCelsius() {
    let conditions = OutdoorConditions(celsius: 21.5, timestamp: baseDate)
    let content = snapshotContent(
        conditions: conditions,
        widget: OutdoorTemperatureWidget().celsius()
    )

    #expect(content?.primaryText == "22°C")
}

@Test func outdoorHideConditionRemovesSecondaryText() {
    let conditions = OutdoorConditions(
        celsius: 20,
        condition: "Overcast",
        timestamp: baseDate
    )
    let content = snapshotContent(
        conditions: conditions,
        widget: OutdoorTemperatureWidget().showCondition(false)
    )

    #expect(content?.secondaryText == nil)
}

@Test func outdoorLocationModifierSetsMetadata() {
    let conditions = OutdoorConditions(celsius: 20, timestamp: baseDate)
    let content = snapshotContent(
        conditions: conditions,
        widget: OutdoorTemperatureWidget().location("Rexburg, ID")
    )

    let location = content?.metadata.first { $0.label == "Location" }?.value
    #expect(location == "Rexburg, ID")
}

// MARK: - Staleness

@Test func outdoorFlagsStaleReading() {
    let stale = OutdoorConditions(celsius: 20, timestamp: baseDate)
    let content = snapshotContent(
        conditions: stale,
        tickAt: baseDate.addingTimeInterval(
            OutdoorTemperatureWidgetModel.stalenessThreshold + 1
        )
    )

    #expect(content?.accessoryText == "STALE")
}

@Test func outdoorFreshReadingIsNotStale() {
    let conditions = OutdoorConditions(celsius: 20, timestamp: baseDate)
    let content = snapshotContent(
        conditions: conditions,
        tickAt: baseDate.addingTimeInterval(60)
    )

    #expect(content?.accessoryText == nil)
}

// MARK: - Open-Meteo parsing

@Test func openMeteoParsesCurrentConditions() {
    let json = Data("""
    {"current":{"temperature_2m":12.3,"relative_humidity_2m":48,"weather_code":3}}
    """.utf8)

    let conditions = OpenMeteoOutdoorService.parse(json, timestamp: baseDate)

    #expect(conditions?.celsius == 12.3)
    #expect(conditions?.humidity == 48)
    #expect(conditions?.condition == "Overcast")
    #expect(conditions?.timestamp == baseDate)
}

@Test func openMeteoParseReturnsNilWithoutTemperature() {
    let json = Data(#"{"current":{"relative_humidity_2m":48}}"#.utf8)

    #expect(OpenMeteoOutdoorService.parse(json, timestamp: baseDate) == nil)
}

@Test func openMeteoMapsWeatherCodes() {
    #expect(OpenMeteoOutdoorService.conditionText(forWeatherCode: 0) == "Clear")
    #expect(OpenMeteoOutdoorService.conditionText(forWeatherCode: 2) == "Partly cloudy")
    #expect(OpenMeteoOutdoorService.conditionText(forWeatherCode: 65) == "Rain")
    #expect(OpenMeteoOutdoorService.conditionText(forWeatherCode: 75) == "Snow")
    #expect(OpenMeteoOutdoorService.conditionText(forWeatherCode: 95) == "Thunderstorm")
    #expect(OpenMeteoOutdoorService.conditionText(forWeatherCode: 1234) == "—")
}

@Test func rexburgIsTheDefaultLocation() {
    let service = OpenMeteoOutdoorService()

    #expect(service.location.name == "Rexburg, ID")
    #expect(service.location.latitude == 43.826)
    #expect(service.location.longitude == -111.7897)
}

// MARK: - Simulated source

@Test func simulatedOutdoorServiceProducesReadingNearBase() {
    let service = SimulatedOutdoorService(
        baseCelsius: 12,
        amplitude: 6,
        startDate: baseDate,
        now: { baseDate }
    )

    let conditions = service.currentConditions()
    // At startDate the sine phase is 0, so the reading equals the base.
    #expect(conditions?.celsius == 12)
}
