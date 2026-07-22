import DefaultBackend
import SwiftCrossUI

/// The SwiftCrossUI application. Deliberately has no `@main`: it's launched
/// explicitly by `SwiftCrossUIRenderer.run()` *after* the dashboard has been
/// composed and its observer started, so the model is in place before the
/// window opens. Uses `DefaultBackend` (AppKit on macOS, GTK on Linux/Pi).
struct DashboardApp: App {
    var body: some Scene {
        WindowGroup("DeskDashboard") {
            DashboardRootView()
        }
    }
}
