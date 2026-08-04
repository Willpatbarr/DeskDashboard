import DashboardKit
import Testing

@Test func standardLayoutBuildsHeaderPrimarySecondaryAndMetadata() {
    let content = WidgetContent(
        title: "Clock",
        primaryText: "10:00",
        secondaryText: "Monday",
        accessoryText: "STALE",
        metadata: [WidgetContentMetadata(label: "Refresh", value: "1s")]
    )

    #expect(WidgetLayout.standard.makeView(content) == .stack(.vertical, spacing: 6, [
        .stack(.horizontal, spacing: 8, [
            .text("Clock", role: .title),
            .spacer,
            .badge("STALE"),
        ]),
        .text("10:00", role: .primary),
        .text("Monday", role: .secondary),
        .spacer,
        .text("Refresh: 1s", role: .caption),
    ]))
}

@Test func standardLayoutOmitsAbsentSlots() {
    let content = WidgetContent(primaryText: "72°F")

    #expect(WidgetLayout.standard.makeView(content) == .stack(.vertical, spacing: 6, [
        .stack(.horizontal, spacing: 8, [.spacer]),
        .text("72°F", role: .primary),
        .spacer,
    ]))
}

@Test func bigNumberLayoutIsCaptionTitleThenHero() {
    let content = WidgetContent(title: "Indoor", primaryText: "71°F")

    #expect(WidgetLayout.bigNumber.makeView(content) == .stack(.vertical, spacing: 2, [
        .text("Indoor", role: .title),
        .text("71°F", role: .hero),
    ]))
}

@Test func centeredValueLayoutKeepsTitleAtTopAndCentersTheValue() {
    let content = WidgetContent(
        title: "Clock",
        primaryText: "9:21",
        secondaryText: "Tuesday, Aug 4"
    )

    // Title first (so it stays top-left), then spacers around a `.centered` block
    // — the spacers centre it vertically, `.centered` horizontally.
    #expect(WidgetLayout.centeredValue.makeView(content) == .stack(.vertical, spacing: 2, [
        .text("Clock", role: .title),
        .spacer,
        .centered([.text("9:21", role: .display)]),
        .centered([.text("Tuesday, Aug 4", role: .secondary)]),
        .spacer,
    ]))
}

@Test func centeredValueLayoutOmitsAbsentSlots() {
    #expect(WidgetLayout.centeredValue.makeView(WidgetContent(primaryText: "71°F"))
        == .stack(.vertical, spacing: 2, [
            .spacer,
            .centered([.text("71°F", role: .display)]),
            .spacer,
        ]))
}
