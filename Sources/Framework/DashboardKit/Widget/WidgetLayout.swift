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

    public func makeView(_ content: WidgetContent) -> WidgetView {
        switch self {
        case .standard: Self.makeStandard(content)
        case .bigNumber: Self.makeBigNumber(content)
        case .stat: Self.makeStat(content)
        case .compact: Self.makeCompact(content)
        case .minimal: Self.makeMinimal(content)
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

    /// "Label: value · Label: value" — the metadata footer, or nil if empty.
    private static func metadataLine(_ content: WidgetContent) -> String? {
        guard !content.metadata.isEmpty else { return nil }
        return content.metadata
            .map { "\($0.label): \($0.value)" }
            .joined(separator: " · ")
    }
}
