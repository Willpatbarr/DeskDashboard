// NowPlayingLayout.swift — Tile layout: `mediaStacked` plus a bottom transport row with times and progress.

public extension WidgetLayout {
    /// `mediaStacked` plus a transport row pinned to the tile's bottom: a
    /// play/pause glyph and a progress line (from `content.isPlaying` /
    /// `content.progress`; either alone still shows, both absent hides the row),
    /// with elapsed/duration readouts above the line's ends when present.
    /// Built for the Music tile.
    ///
    /// Composes `.mediaStacked` from the file next door rather than restating it —
    /// layouts are reusable by name across files, same as theme tokens.
    static let nowPlaying = Self(id: "nowPlaying") { content in
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
        let stacked = WidgetLayout.mediaStacked.makeView(content)
        guard !transport.isEmpty else { return stacked }

        return .stack(.vertical, spacing: 6, [
            stacked,
            .spacer,
            .stack(.horizontal, spacing: 10, transport),
        ])
    }
}
