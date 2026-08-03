import DashboardKit
import Foundation
import SwiftCrossUI

/// The curated "green board": a four-tile dashboard on the gradient-clock theme —
/// clock, music, indoor temp, outdoor temp, in that order (no alarm tile).
///
/// - All four tiles are forced to **equal width** via a `GeometryReader` (each
///   gets `1/4` of the row rather than sizing to its content).
/// - The clock shows a **big, minute-precision** time built locally, so it never
///   shows seconds regardless of the clock widget's `showSeconds` option.
/// - Music uses `.mediaCompact` (smaller title text) so long song titles fit.
/// - The temps use `.standard`, unchanged.
struct CuratedGreenView: View {
    let palette: ThemePalette
    let snapshots: [AttachedWidgetSnapshot]

    /// Minute-precision, no seconds. Rebuilt each render (snapshots tick ~1s).
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    var body: some View {
        GeometryReader { proxy in
            let count = 4
            let gap = palette.widgetGap
            let available = proxy.size.width - Double(gap * (count - 1))
            let tileWidth = max(1, available / Double(count))

            HStack(spacing: gap) {
                clockTile.frame(width: tileWidth).tileCorners(palette)
                ForEach(snapshotTiles, id: \.snapshot.id.rawValue) { item in
                    TileView(
                        snapshot: item.snapshot,
                        palette: palette,
                        layoutOverride: item.layout
                    )
                    .frame(width: tileWidth)
                    .tileCorners(palette)
                }
            }
        }
    }

    private func snapshot(_ id: String) -> AttachedWidgetSnapshot? {
        snapshots.first { $0.id.rawValue == id }
    }

    /// The three snapshot-backed tiles, resolved up front.
    ///
    /// Deliberately *not* an `@ViewBuilder` with `if let` per tile: that wraps each
    /// tile in an optional view, and on the GTK backend those tiles rendered with
    /// **square corners** while the plainly-constructed clock tile kept its
    /// rounded ones. Resolving the snapshots first keeps every tile on the same
    /// unwrapped path.
    private var snapshotTiles: [(snapshot: AttachedWidgetSnapshot, layout: WidgetLayout)] {
        [("music", WidgetLayout.mediaCompact), ("indoor", .standard), ("outdoor", .standard)]
            .compactMap { id, layout in
                snapshot(id).map { (snapshot: $0, layout: layout) }
            }
    }

    /// The clock tile — a `.bigNumber`-style stack (title / hero / date) built
    /// by hand so the time is minute-precision. Roles mirror `TileView.style`
    /// so it matches the other tiles visually.
    private var clockTile: some View {
        VStack(alignment: .leading, spacing: Int((2 * palette.verticalScale).rounded())) {
            Text("CLOCK")
                .font(.system(size: palette.captionSize, weight: palette.bodyWeight))
                .foregroundColor(palette.secondary)
            Text(Self.timeFormatter.string(from: Date()))
                .font(.system(size: palette.headingSize * 1.6, weight: palette.headingWeight))
                .foregroundColor(palette.primary)
            if let date = snapshot("clock")?.content?.secondaryText {
                Text(date)
                    .font(.system(size: palette.bodySize, weight: palette.bodyWeight))
                    .foregroundColor(palette.text)
            }
        }
        .padding(.horizontal, palette.tilePadding)
        .padding(.vertical, palette.verticalTilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface)
        .cornerRadius(Int(palette.cornerRadius.rounded()))
    }
}
