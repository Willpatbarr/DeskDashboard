import DashboardKit
import SwiftCrossUI

/// Observable state backing the SwiftCrossUI dashboard.
///
/// The renderer pushes fresh widget snapshots into `snapshots` on every tick;
/// SwiftCrossUI observes the `@Published` change (via the view's `@State`) and
/// re-renders. This is the real-UI analogue of the dev renderers' `render(_:)`
/// call — same input (`[AttachedWidgetSnapshot]`), different sink.
final class DashboardModel: ObservableObject {
    @Published var snapshots: [AttachedWidgetSnapshot]
    let palette: ThemePalette
    let themeName: String

    init(theme: any Theme, snapshots: [AttachedWidgetSnapshot] = []) {
        self.palette = ThemePalette(theme: theme)
        self.themeName = theme.name
        self.snapshots = snapshots
    }
}

/// Hand-off point between the app-composition code and the SwiftCrossUI `App`.
///
/// `App.main()` constructs the app via a no-argument `init()`, so there's no way
/// to pass the model in directly. The renderer stashes the model here just
/// before launching; `DashboardRootView` reads it once into its `@State`.
enum DashboardLaunch {
    nonisolated(unsafe) static var model: DashboardModel?
}
