// NowPlayingCenteredLayout.swift — Tile layout: nowPlaying with the text centred.

public extension WidgetLayout {
    /// `nowPlaying`, but with the label, artist and song each centred across the
    /// tile instead of leading-aligned. The transport row is untouched: same
    /// play/pause glyph, same times-over-progress-line, same bottom placement.
    ///
    /// Each line gets its own `.centered` group rather than one group wrapping all
    /// three. Two reasons:
    /// - One group would centre the *block* while leaving the lines left-aligned
    ///   relative to each other, which is not what "centred" means here.
    /// - `.centered` carries a negative inter-line spacing tuned for the clock's
    ///   value-plus-subtitle pair (≈ −0.03em); applied across three media lines it
    ///   would crush them together. Per-line groups keep `mediaStacked`'s measured
    ///   12/6 spacing, so this reads like its sibling with the text moved.
    static let nowPlayingCentered = Self(id: "nowPlayingCentered") { content in
        var body: [WidgetView] = []
        if let artist = content.secondaryText {
            body.append(.centered([.text(artist, role: .secondary)]))
        }
        body.append(.centered([.text(content.primaryText, role: .primary)]))
        if let accessory = content.accessoryText {
            body.append(.centered([.badge(accessory)]))
        }

        // Same join as `mediaStacked`: the label→artist gap needs the wider spacing
        // because a body-sized box leaves less air above its cap than a heading-sized
        // one, and with no artist line the song sits directly under the label.
        let titleGap = content.secondaryText == nil ? 6.0 : 12.0
        var stacked = WidgetView.stack(.vertical, spacing: 6, body)
        if let title = content.title {
            stacked = .stack(.vertical, spacing: titleGap, [
                .centered([.text(title, role: .title)]),
                .stack(.vertical, spacing: 6, body),
            ])
        }

        var transport: [WidgetView] = []
        if let isPlaying = content.isPlaying {
            transport.append(.playState(playing: isPlaying))
        }
        if let progress = content.progress {
            let bar = WidgetView.progressBar(max(0, min(1, progress)))
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
        guard !transport.isEmpty else { return stacked }

        return .stack(.vertical, spacing: 6, [
            stacked,
            .spacer,
            .stack(.horizontal, spacing: 10, transport),
        ])
    }
}
