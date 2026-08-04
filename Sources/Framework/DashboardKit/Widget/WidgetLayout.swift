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

    public func makeView(_ content: WidgetContent) -> WidgetView {
        switch self {
        case .standard: Self.makeStandard(content)
        case .bigNumber: Self.makeBigNumber(content)
        case .stat: Self.makeStat(content)
        case .compact: Self.makeCompact(content)
        case .minimal: Self.makeMinimal(content)
        case .centeredValue: Self.makeCenteredValue(content)
        case .mediaCompact: Self.makeMediaCompact(content)
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
            value.append(.text(secondary, role: .secondary))
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

    /// "Label: value · Label: value" — the metadata footer, or nil if empty.
    private static func metadataLine(_ content: WidgetContent) -> String? {
        guard !content.metadata.isEmpty else { return nil }
        return content.metadata
            .map { "\($0.label): \($0.value)" }
            .joined(separator: " · ")
    }
}
