// ScrollFadeGTK.swift — Fades a scroll region's clipped edges, using GTK's undershoot nodes.

import SwiftCrossUI

#if canImport(GtkBackend)
    import Gtk
    import GtkBackend
#endif

// Fifth file allowed to `import Gtk`, for the same reason as the other four
// (`TextToGTKTracking`, `PressReleaseGTK`, `TileBorderGTK`,
// `TapUnlessDraggedGTK`): Gtk exports its own `Color`/`Font`, so the import
// stays quarantined or every other file's type lookup turns ambiguous.

/// Styles GTK's `undershoot` nodes so content fades out where a scroll region
/// clips it.
///
/// `undershoot.top` / `undershoot.bottom` are nodes GTK draws over a
/// `scrolledwindow`'s content edge, and **only while there is more content in
/// that direction** — which is exactly when a card is being clipped. They are
/// decoration, not widgets, so unlike an overlay they cannot swallow the taps
/// or drags underneath them (the trap documented in `TileBorderGTK`).
///
/// A true per-pixel alpha mask would be the obvious approach and is not
/// available: GTK 4.8 has no `mask-image` (checked against the Pi's own
/// libgtk-4). Fading to the container's colour reads the same, since what sits
/// behind the cards is a flat well.
///
/// **The rules are display-wide**, not per widget: GTK per-widget CSS sets
/// properties on the widget itself and cannot reach its internal child nodes.
/// That is honest for this app — the session board is its only scroll region —
/// but it does mean the last colour installed wins if a second one ever
/// appears. Installing is idempotent per colour+height, so the once-a-second
/// re-render doesn't churn providers.
enum ScrollFade {
    #if canImport(GtkBackend)
        nonisolated(unsafe) private static var provider: CSSProvider?
        nonisolated(unsafe) private static var installed: String?
    #endif

    /// Installs (or updates) the fade for a `hex` container colour, fading over
    /// `height` pixels at each clipped edge.
    static func install(hex: String, height: Double) {
        #if canImport(GtkBackend)
            let px = max(1, Int(height.rounded()))
            let key = "\(hex)@\(px)"
            guard installed != key else { return }
            installed = key

            // GTK needs an alpha stop that keeps the same RGB, or the gradient
            // runs through black on its way to transparent.
            let clear = transparentForm(of: hex)
            let css = """
            scrolledwindow undershoot.top {
              box-shadow: none;
              background-image: linear-gradient(to bottom, \(hex) 0%, \(clear) 100%);
              background-size: 100% \(px)px;
              background-position: top center;
              background-repeat: no-repeat;
              min-height: \(px)px;
            }
            scrolledwindow undershoot.bottom {
              box-shadow: none;
              background-image: linear-gradient(to top, \(hex) 0%, \(clear) 100%);
              background-size: 100% \(px)px;
              background-position: bottom center;
              background-repeat: no-repeat;
              min-height: \(px)px;
            }
            """
            let provider = provider ?? CSSProvider()
            Self.provider = provider
            provider.loadCss(from: css)
        #endif
    }

    /// `#rrggbb` as a fully transparent `rgba()` of the SAME rgb, so a gradient
    /// to it fades out instead of darkening toward black on the way.
    static func transparentForm(of hex: String) -> String {
        var digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if digits.count == 8 { digits = String(digits.prefix(6)) }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            return "transparent"
        }
        let r = (value >> 16) & 0xFF
        let g = (value >> 8) & 0xFF
        let b = value & 0xFF
        return "rgba(\(r),\(g),\(b),0)"
    }
}
