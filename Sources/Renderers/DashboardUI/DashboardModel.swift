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
    /// Index into `previews`; advanced by `nextPreview()` (the toggle button).
    @Published private(set) var previewIndex = 0

    /// Whether to show the preview toggle button (the `--preview` flag).
    let showsPreviewControls: Bool
    /// Curated theme × layout combinations to cycle through. Index 0 is the
    /// real configuration (the composition's theme, each widget's own layout).
    let previews: [Preview]

    struct Preview {
        let name: String
        let theme: any Theme
        /// A layout to force on every tile, or `nil` to use each widget's own.
        let layout: WidgetLayout?
    }

    init(
        theme: any Theme,
        snapshots: [AttachedWidgetSnapshot] = [],
        showsPreviewControls: Bool = false
    ) {
        self.snapshots = snapshots
        self.showsPreviewControls = showsPreviewControls
        self.previews = [
            Preview(name: theme.name, theme: theme, layout: nil),
            Preview(name: "Dark · big number", theme: DarkDeskTheme(), layout: .bigNumber),
            Preview(name: "Dark · stat", theme: DarkDeskTheme(), layout: .stat),
            Preview(name: "Light · standard",
                    theme: DarkDeskTheme(name: "Light", colors: .light), layout: .standard),
            Preview(name: "Light · compact",
                    theme: DarkDeskTheme(name: "Light", colors: .light), layout: .compact),
            Preview(name: "Neon · minimal",
                    theme: DarkDeskTheme(name: "Neon", colors: .neon), layout: .minimal),
        ]
    }

    private var current: Preview { previews[previewIndex] }
    var palette: ThemePalette { ThemePalette(theme: current.theme) }
    /// A layout forced on every tile for the current preview, or `nil`.
    var layoutOverride: WidgetLayout? { current.layout }
    var previewName: String { current.name }

    /// Jump straight to a preview by index (a segment tap). Out-of-range is
    /// ignored. This is the hook a real layout switcher would drive too.
    func select(_ index: Int) {
        guard previews.indices.contains(index) else { return }
        previewIndex = index
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
