// RailFilterBar.swift — What the fullscreen rail's filter pills are, as configuration.

/// A group of toggle pills for the fullscreen rail's bottom edge.
///
/// Deliberately opaque: `DashboardUI` is shell chrome and knows nothing about
/// Claude sessions — or whatever else might one day want a rail filter — so it
/// is handed the labels to draw and reports back the ones that are lit. The
/// meaning of a key lives entirely in the app that supplied it.
///
/// Every tap sends the WHOLE lit selection as one action
/// (`actionPrefix` + the lit keys, comma-separated, in `keys` order) rather than
/// a toggle verb. That makes the action idempotent, keeps the ordering stable
/// regardless of `Set` iteration, and means the widget never has to be read back
/// to find out what it thinks is on.
public struct RailFilterBar: Equatable, Sendable {
    /// The widget the actions are addressed to. Also gates the pills: they only
    /// draw on a board that actually contains this widget.
    public let widgetID: String
    /// Prepended to the comma-joined selection to make the action string.
    public let actionPrefix: String
    /// Pill labels, left to right — and the tokens the selection is spelled in.
    public let keys: [String]

    public init(widgetID: String, actionPrefix: String, keys: [String]) {
        self.widgetID = widgetID
        self.actionPrefix = actionPrefix
        self.keys = keys
    }
}
