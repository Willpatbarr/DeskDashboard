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
                clockTile.frame(width: tileWidth)
                tile(id: "music", layout: .mediaCompact).frame(width: tileWidth)
                tile(id: "indoor", layout: .standard).frame(width: tileWidth)
                tile(id: "outdoor", layout: .standard).frame(width: tileWidth)
            }
        }
    }

    private func snapshot(_ id: String) -> AttachedWidgetSnapshot? {
        snapshots.first { $0.id.rawValue == id }
    }

    /// A snapshot-backed tile rendered through the shared `TileView` with a
    /// forced layout. Empty if that widget isn't in the snapshot set.
    @ViewBuilder
    private func tile(id: String, layout: WidgetLayout) -> some View {
        if let snapshot = snapshot(id) {
            TileView(snapshot: snapshot, palette: palette, layoutOverride: layout)
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
