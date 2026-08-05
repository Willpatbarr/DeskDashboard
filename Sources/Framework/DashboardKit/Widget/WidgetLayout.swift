/// A prebuilt tile layout — a pure mapping from a widget's semantic
/// `WidgetContent` to a `WidgetView` tree. Pick one per widget with
/// `.layout(_:)`; the renderer interprets the resulting tree.
///
/// These are backend-agnostic (no fonts/colors/pixels), so the same layout works
/// in every renderer. Add a new arrangement by adding a case + a builder here —
/// no renderer changes needed for renderers that already interpret `WidgetView`.
public enum WidgetLayout: Sendable, Equatable {
    /// Title + badge row, primary value, secondary line, metadata footer.
    /// The default; matches the original tile arrangement.
    case standard
    /// A big value with a small caption title above — good for a clock or a
    /// single temperature/number.
    case bigNumber
    /// A big value with the label *underneath* it (dashboard-stat style), plus
    /// any badge.
    case stat
    /// Tight: title + value + secondary line, no metadata footer.
    case compact
    /// Just the value, nothing else.
    case minimal
    /// Title parked at the top-left, with the value (and its supporting line)
    /// centred **horizontally** and top-aligned vertically — the value container
    /// starts right below the title, exactly where every other layout puts its
    /// value, so a row of tiles lines up. For a tile whose value is the
    /// centrepiece, like the board's clock.
    case centeredValue
    /// Media/now-playing: title label, the primary value at *supporting* size
    /// (not the big primary role) so long song titles fit, a caption subline,
    /// and any badge. Good for the Music tile.
    case mediaCompact
    /// Media/now-playing with the song title as the centrepiece: title label,
    /// then the artist line, then the song at full `.primary` size — last so it
    /// can wrap over multiple lines (that's how long titles fit here, instead of
    /// `mediaCompact`'s smaller type) without pushing the lines above around.
    /// Vertical spacing matches `.standard`, so the label→artist gap lines up
    /// with the temp tiles' label→value gap.
    case mediaStacked
    /// `mediaStacked` plus a transport row pinned to the tile's bottom: a
    /// play/pause glyph and a progress line (from `content.isPlaying` /
    /// `content.progress`; either alone still shows, both absent hides the row),
    /// with elapsed/duration readouts above the line's ends when present.
    /// Built for the Music tile.
    case nowPlaying
    /// The title centred at the top, then the value alone filling ALL remaining
    /// space, sized by the renderer to fit — the number scales with the widget.
    /// No secondary line, no metadata. For a temperature in a small tile.
    case fittedValue

    public func makeView(_ content: WidgetContent) -> WidgetView {
        switch self {
        case .standard: Self.makeStandard(content)
        case .bigNumber: Self.makeBigNumber(content)
        case .stat: Self.makeStat(content)
        case .compact: Self.makeCompact(content)
        case .minimal: Self.makeMinimal(content)
        case .centeredValue: Self.makeCenteredValue(content)
        case .mediaCompact: Self.makeMediaCompact(content)
        case .mediaStacked: Self.makeMediaStacked(content)
        case .nowPlaying: Self.makeNowPlaying(content)
        case .fittedValue: Self.makeFittedValue(content)
        }
    }

    // MARK: - Builders

    private static func makeStandard(_ content: WidgetContent) -> WidgetView {
        var header: [WidgetView] = []
        if let title = content.title {
            header.append(.text(title, role: .title))
        }
        header.append(.spacer)
        if let accessory = content.accessoryText {
            header.append(.badge(accessory))
        }

        var children: [WidgetView] = [
            .stack(.horizontal, spacing: 8, header),
            .text(content.primaryText, role: .primary),
        ]
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .secondary))
        }
        children.append(.spacer)
        if let metadata = metadataLine(content) {
            children.append(.text(metadata, role: .caption))
        }

        return .stack(.vertical, spacing: 6, children)
    }

    private static func makeBigNumber(_ content: WidgetContent) -> WidgetView {
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.text(title, role: .title))
        }
        children.append(.text(content.primaryText, role: .hero))
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .secondary))
        }
        return .stack(.vertical, spacing: 2, children)
    }

    private static func makeStat(_ content: WidgetContent) -> WidgetView {
        var children: [WidgetView] = [.text(content.primaryText, role: .hero)]
        if let title = content.title {
            children.append(.text(title, role: .caption))
        }
        if let accessory = content.accessoryText {
            children.append(.badge(accessory))
        }
        return .stack(.vertical, spacing: 2, children)
    }

    private static func makeCompact(_ content: WidgetContent) -> WidgetView {
        var header: [WidgetView] = []
        if let title = content.title {
            header.append(.text(title, role: .title))
        }
        header.append(.spacer)
        if let accessory = content.accessoryText {
            header.append(.badge(accessory))
        }

        var children: [WidgetView] = [
            .stack(.horizontal, spacing: 8, header),
            .text(content.primaryText, role: .primary),
        ]
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .secondary))
        }
        return .stack(.vertical, spacing: 4, children)
    }

    private static func makeMinimal(_ content: WidgetContent) -> WidgetView {
        .stack(.vertical, spacing: 0, [.text(content.primaryText, role: .hero)])
    }

    private static func makeCenteredValue(_ content: WidgetContent) -> WidgetView {
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.text(title, role: .title))
        }

        // Both lines in one `.centered` group so they share a centre line, and the
        // group sits directly under the title with only a *trailing* spacer: that
        // top-aligns it with the values in neighbouring tiles instead of floating it
        // in the middle of its own tile.
        var value: [WidgetView] = [.text(content.primaryText, role: .display)]
        if let secondary = content.secondaryText {
            value.append(.text(secondary, role: .subtitle))
        }
        children.append(.centered(value))
        children.append(.spacer)

        return .stack(.vertical, spacing: 2, children)
    }

    private static func makeMediaCompact(_ content: WidgetContent) -> WidgetView {
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.text(title, role: .title))
        }
        // Primary at the smaller `.secondary` size so a long song title fits.
        children.append(.text(content.primaryText, role: .secondary))
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .caption))
        }
        if let accessory = content.accessoryText {
            children.append(.badge(accessory))
        }
        return .stack(.vertical, spacing: 4, children)
    }

    private static func makeMediaStacked(_ content: WidgetContent) -> WidgetView {
        var body: [WidgetView] = []
        if let secondary = content.secondaryText {
            body.append(.text(secondary, role: .secondary))
        }
        body.append(.text(content.primaryText, role: .primary))
        if let accessory = content.accessoryText {
            body.append(.badge(accessory))
        }

        guard let title = content.title else {
            return .stack(.vertical, spacing: 6, body)
        }
        // The label→artist ink gap should read the same as `.standard`'s
        // label→value gap in the temp tiles, but spacing separates label BOXES,
        // and the artist's body-sized box leaves less air above its cap than the
        // heading-sized temp values do — measured 24px vs 33px on the panel at
        // spacing 6. The extra 6 units at this one join squares the inks up.
        // With no artist line, the primary sits right under the title exactly
        // like `.standard`, so plain spacing 6 already matches.
        let titleGap = content.secondaryText == nil ? 6.0 : 12.0
        return .stack(.vertical, spacing: titleGap, [
            .text(title, role: .title),
            .stack(.vertical, spacing: 6, body),
        ])
    }

    private static func makeNowPlaying(_ content: WidgetContent) -> WidgetView {
        var transport: [WidgetView] = []
        if let isPlaying = content.isPlaying {
            transport.append(.playState(playing: isPlaying))
        }
        if let progress = content.progress {
            let bar = WidgetView.progressBar(max(0, min(1, progress)))
            // Time readouts sit in a row of their own directly above the line —
            // elapsed over its leading end, duration over its trailing end —
            // grouped with the bar (not the play glyph) so they align with the
            // line itself.
            var times: [WidgetView] = []
            if let elapsed = content.elapsedText {
                times.append(.text(elapsed, role: .caption))
            }
            if let duration = content.durationText {
                times.append(.spacer)
                times.append(.text(duration, role: .caption))
            }
            if times.isEmpty {
                transport.append(bar)
            } else {
                transport.append(.stack(.vertical, spacing: 4, [
                    .stack(.horizontal, spacing: 8, times),
                    bar,
                ]))
            }
        }
        guard !transport.isEmpty else { return makeMediaStacked(content) }

        return .stack(.vertical, spacing: 6, [
            makeMediaStacked(content),
            .spacer,
            .stack(.horizontal, spacing: 10, transport),
        ])
    }

    private static func makeFittedValue(_ content: WidgetContent) -> WidgetView {
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.centered([.text(title, role: .title)]))
        }
        children.append(.fittedText(content.primaryText))
        return .stack(.vertical, spacing: 2, children)
    }

    /// "Label: value · Label: value" — the metadata footer, or nil if empty.
    private static func metadataLine(_ content: WidgetContent) -> String? {
        guard !content.metadata.isEmpty else { return nil }
        return content.metadata
            .map { "\($0.label): \($0.value)" }
            .joined(separator: " · ")
    }
}
