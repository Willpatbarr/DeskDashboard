import DashboardKit
import SwiftCrossUI

/// A single widget tile — the SwiftCrossUI counterpart of the dev web
/// renderer's `.tile` element. Reads its text from the snapshot's
/// `WidgetContent`, falling back to the configured title when there's no
/// content yet.
struct TileView: View {
    let snapshot: AttachedWidgetSnapshot
    let palette: ThemePalette

    private var title: String? {
        snapshot.content?.title ?? snapshot.configuration.title
    }

    private var metadataLine: String? {
        guard let metadata = snapshot.content?.metadata, !metadata.isEmpty else {
            return nil
        }
        return metadata.map { "\($0.label): \($0.value)" }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let title {
                    Text(title.uppercased())
                        .font(.system(size: palette.captionSize, weight: palette.bodyWeight))
                        .foregroundColor(palette.secondary)
                }
                Spacer(minLength: 0)
                if let accessory = snapshot.content?.accessoryText {
                    Text(accessory)
                        .font(.system(size: palette.captionSize, weight: .bold))
                        .foregroundColor(palette.accent)
                }
            }

            Text(snapshot.content?.primaryText ?? "…")
                .font(.system(size: palette.headingSize, weight: palette.headingWeight))
                .foregroundColor(palette.primary)

            if let secondary = snapshot.content?.secondaryText {
                Text(secondary)
                    .font(.system(size: palette.bodySize, weight: palette.bodyWeight))
                    .foregroundColor(palette.text)
            }

            Spacer(minLength: 0)

            if let metadataLine {
                Text(metadataLine)
                    .font(.system(size: palette.captionSize, weight: palette.bodyWeight))
                    .foregroundColor(palette.muted)
            }
        }
        .padding(palette.tilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface)
        .cornerRadius(Int(palette.cornerRadius.rounded()))
    }
}
