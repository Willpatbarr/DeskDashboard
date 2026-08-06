// WidgetLayout.swift — Layout scaffold: `WidgetContent` to `WidgetView`; each lives in `Layouts/`.

/// A prebuilt tile layout — a pure mapping from a widget's semantic
/// `WidgetContent` to a `WidgetView` tree. Pick one per widget with
/// `.layout(_:)`; the renderer interprets the resulting tree.
///
/// Layouts are backend-agnostic (no fonts/colors/pixels), so the same layout
/// works in every renderer.
///
/// **This file is the scaffold.** Every layout lives in its own file under
/// `Layouts/`, declared as a static on this type:
///
///     public extension WidgetLayout {
///         static let myLayout = Self(id: "myLayout") { content in
///             .stack(.vertical, spacing: 6, [ … ])
///         }
///     }
///
/// So adding an arrangement is one new file — nothing to edit here, and no
/// renderer changes for renderers that already interpret `WidgetView`.
///
/// It's a struct rather than an enum for exactly that reason: enum cases can only
/// be declared in the enum's own declaration, which would force every new layout
/// to also edit this file twice (a `case` plus a `switch` arm). The cost is that
/// layouts aren't exhaustively switchable and there's no free `CaseIterable` —
/// neither of which anything needs, since a layout is only ever *applied*.
public struct WidgetLayout: Sendable, Equatable {
    /// Stable name, used for equality and for logs. Unique per layout — see
    /// `layoutIDsAreUnique` in the tests.
    public let id: String

    private let build: @Sendable (WidgetContent) -> WidgetView

    public init(
        id: String,
        _ build: @escaping @Sendable (WidgetContent) -> WidgetView
    ) {
        self.id = id
        self.build = build
    }

    public func makeView(_ content: WidgetContent) -> WidgetView {
        build(content)
    }

    /// Identity is the `id`: two layouts are the same layout if they're named the
    /// same. Closures can't be compared, and `WidgetConfiguration` /
    /// the board's `BoardColumn` both need `Equatable` to synthesize theirs.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Shared helpers for layout files

    /// "Label: value · Label: value" — the metadata footer, or nil if empty.
    static func metadataLine(_ content: WidgetContent) -> String? {
        guard !content.metadata.isEmpty else { return nil }
        return content.metadata
            .map { "\($0.label): \($0.value)" }
            .joined(separator: " · ")
    }
}
