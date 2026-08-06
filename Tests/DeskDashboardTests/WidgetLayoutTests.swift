// WidgetLayoutTests.swift — Tests: each tile layout's view tree, plus the layout scaffold's contract.

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
        .centered([
            .text("9:21", role: .display),
            .text("Tuesday, Aug 4", role: .subtitle),
        ]),
        .spacer,
    ]))
}

@Test func mediaStackedLayoutPutsArtistAboveFullSizeSongTitle() {
    let content = WidgetContent(
        title: "Music",
        primaryText: "Snake Eyes",
        secondaryText: "Mumford & Sons",
        accessoryText: "PAUSED"
    )

    // Artist ABOVE the song, song last at full `.primary` size so wrapping it
    // over multiple lines never pushes the lines above around. The title joins
    // the body at a wider spacing (12 vs 6) so the label→artist INK gap matches
    // the temps' label→value gap (boxes differ: body-sized vs heading-sized).
    #expect(WidgetLayout.mediaStacked.makeView(content) == .stack(.vertical, spacing: 12, [
        .text("Music", role: .title),
        .stack(.vertical, spacing: 6, [
            .text("Mumford & Sons", role: .secondary),
            .text("Snake Eyes", role: .primary),
            .badge("PAUSED"),
        ]),
    ]))
}

@Test func mediaStackedLayoutOmitsAbsentSlots() {
    #expect(WidgetLayout.mediaStacked.makeView(WidgetContent(primaryText: "Nothing playing"))
        == .stack(.vertical, spacing: 6, [
            .text("Nothing playing", role: .primary),
        ]))
}

@Test func nowPlayingLayoutPinsTransportRowBelowTheMediaStack() {
    let content = WidgetContent(
        title: "Music",
        primaryText: "Snake Eyes",
        secondaryText: "Mumford & Sons",
        progress: 0.25,
        isPlaying: true
    )

    #expect(WidgetLayout.nowPlaying.makeView(content) == .stack(.vertical, spacing: 6, [
        WidgetLayout.mediaStacked.makeView(content),
        .spacer,
        .stack(.horizontal, spacing: 10, [
            .playState(playing: true),
            .progressBar(0.25),
        ]),
    ]))
}

@Test func nowPlayingLayoutPutsTimeReadoutsAboveTheBarEnds() {
    let content = WidgetContent(
        title: "Music",
        primaryText: "Nightcall",
        secondaryText: "Kavinsky",
        progress: 0.5,
        elapsedText: "2:09",
        durationText: "4:18",
        isPlaying: true
    )

    #expect(WidgetLayout.nowPlaying.makeView(content) == .stack(.vertical, spacing: 6, [
        WidgetLayout.mediaStacked.makeView(content),
        .spacer,
        .stack(.horizontal, spacing: 10, [
            .playState(playing: true),
            .stack(.vertical, spacing: 4, [
                .stack(.horizontal, spacing: 8, [
                    .text("2:09", role: .caption),
                    .spacer,
                    .text("4:18", role: .caption),
                ]),
                .progressBar(0.5),
            ]),
        ]),
    ]))
}

@Test func fittedValueLayoutIsACenteredLabelOverAFittedNumber() {
    let content = WidgetContent(title: "Indoor", primaryText: "71°F", secondaryText: "44% humidity")

    // No secondary line, no metadata — just the centred label and the value.
    #expect(WidgetLayout.fittedValue.makeView(content) == .stack(.vertical, spacing: 2, [
        .centered([.text("Indoor", role: .title)]),
        .fittedText("71°F"),
    ]))
}

@Test func nowPlayingLayoutWithoutTransportDataIsJustMediaStacked() {
    let content = WidgetContent(title: "Music", primaryText: "Nothing playing")

    #expect(WidgetLayout.nowPlaying.makeView(content)
        == WidgetLayout.mediaStacked.makeView(content))
}

@Test func centeredValueLayoutOmitsAbsentSlots() {
    #expect(WidgetLayout.centeredValue.makeView(WidgetContent(primaryText: "71°F"))
        == .stack(.vertical, spacing: 2, [
            .centered([.text("71°F", role: .display)]),
            .spacer,
        ]))
}

// MARK: - The scaffold contract

/// Every layout that ships, paired with the name it should carry.
///
/// Deliberately a test-side list, not something in the scaffold: keeping it here
/// means adding a layout still touches only its own file plus this list, rather
/// than the type every layout depends on.
private let allLayouts: [(id: String, layout: WidgetLayout)] = [
    ("standard", .standard),
    ("bigNumber", .bigNumber),
    ("stat", .stat),
    ("compact", .compact),
    ("minimal", .minimal),
    ("centeredValue", .centeredValue),
    ("mediaCompact", .mediaCompact),
    ("mediaStacked", .mediaStacked),
    ("nowPlaying", .nowPlaying),
    ("fittedValue", .fittedValue),
]

/// Layout identity is its `id`, so a duplicated one — easy to introduce by
/// copying a layout file — would make two different layouts compare EQUAL, and
/// silently swap arrangements wherever configs are compared.
@Test func layoutIDsAreUnique() {
    let ids = allLayouts.map(\.layout.id)
    #expect(Set(ids).count == ids.count)
}

/// Catches the other half of a bad copy-paste: an id that doesn't match the
/// member it's attached to.
@Test func eachLayoutCarriesItsOwnName() {
    for (expected, layout) in allLayouts {
        #expect(layout.id == expected)
    }
}

@Test func layoutsCompareByIdentityNotByClosure() {
    // Needed because `WidgetConfiguration` and the board's `Column` both
    // synthesize `Equatable` through this.
    #expect(WidgetLayout.standard == .standard)
    #expect(WidgetLayout.standard != .compact)
    #expect(WidgetConfiguration(layout: .nowPlaying) == WidgetConfiguration(layout: .nowPlaying))
    #expect(WidgetConfiguration(layout: .nowPlaying) != WidgetConfiguration(layout: .mediaStacked))
}

/// A layout is only ever *applied*, so the scaffold needs no knowledge of the
/// arrangements — this proves a layout defined entirely outside DashboardKit
/// works, which is what makes "one new file" true.
@Test func aLayoutCanBeDefinedFromOutsideTheFramework() {
    let custom = WidgetLayout(id: "testOnly") { content in
        .stack(.vertical, spacing: 1, [.text(content.primaryText, role: .hero)])
    }

    #expect(custom.makeView(WidgetContent(primaryText: "42"))
        == .stack(.vertical, spacing: 1, [.text("42", role: .hero)]))
    #expect(custom != .standard)
}
