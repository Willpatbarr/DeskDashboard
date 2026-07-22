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
