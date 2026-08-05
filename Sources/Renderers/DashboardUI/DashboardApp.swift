import DefaultBackend
import SwiftCrossUI

/// The SwiftCrossUI application. Deliberately has no `@main`: it's launched
/// explicitly by `SwiftCrossUIRenderer.run()` *after* the dashboard has been
/// composed and its observer started, so the model is in place before the
/// window opens. Uses `DefaultBackend` (AppKit on macOS, GTK on Linux/Pi).
struct DashboardApp: App {
    var body: some Scene {
        WindowGroup("DeskDashboard") {
            if let forced = DashboardLaunch.forcedWindowSize {
                // Pins the layout to a target panel's geometry (see
                // `DashboardLaunch.forcedWindowSize` for why `defaultSize` alone
                // doesn't do it).
                DashboardRootView()
                    .frame(width: Double(forced.width), height: Double(forced.height))
            } else {
                DashboardRootView()
            }
        }
        .defaultSize(
            width: DashboardLaunch.windowSize.width,
            height: DashboardLaunch.windowSize.height
        )
    }
}
