// InteractiveWidget.swift — Opt-in protocol for widgets that handle taps.

/// A widget that can be interacted with, not just displayed.
///
/// Opt-in exactly like `ServiceBackedWidget`: plain widgets stay one-way (produce
/// `WidgetContent`, know nothing about input), and a widget becomes interactive
/// by conforming. Its layout marks regions with `WidgetView.tappable(action:_:)`,
/// and the renderer reports the action name back here.
///
/// Actions arrive by name rather than as closures so the whole chain stays data:
/// the view tree remains `Equatable`/`Sendable`, and a renderer that can't accept
/// input just draws the child.
///
/// Handle the action by mutating a **service** rather than the widget itself —
/// widgets are value types re-rendered every tick, so state kept on `self` would
/// not survive. Service state shows up on the next snapshot, which is what makes
/// the round trip work.
public protocol InteractiveWidget: Widget {
    /// Responds to an action raised by this widget's own layout.
    func handle(action: String, environment: DashboardEnvironment)
}
