/// The size of the surface the dashboard is drawn on, in points.
public struct Viewport: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(
        width: Double,
        height: Double
    ) {
        self.width = width
        self.height = height
    }

    /// The canvas theme size tokens are authored against: a 1280×800 desk
    /// display. A viewport this size resolves to scale `1`, i.e. the literal
    /// numbers written in `ThemeTypography` / `ThemeSpacing` / `ThemeShape`.
    public static let reference = Self(width: 1280, height: 800)
}

/// How a theme's *size* tokens adapt to the screen they land on.
///
/// The numbers in `ThemeTypography`, `ThemeSpacing` and `ThemeShape` are not
/// pixel values for one display — they're reference values authored at
/// `referenceViewport`. A renderer asks `scale(for:)` for the multiplier that
/// maps that reference canvas onto the real viewport and scales every size token
/// by it, so the same dashboard keeps its proportions on a 1024×600 Pi panel, a
/// 1280×800 window, or a 4K TV.
///
/// By default the scale comes from the **width** alone (see `Basis`). A window
/// that is wide but short — which is what a content-sized dashboard window
/// actually is; the AppKit backend opens this app at roughly 1329×350 — would
/// otherwise have its type crushed by the height term.
public struct ThemeMetrics: Equatable, Sendable {
    /// Which viewport dimension the scale is derived from.
    public enum Basis: Equatable, Sendable {
        /// Width only — the default. A dashboard's tiles are laid out across the
        /// width, and a wide-but-short window still wants readable type, so
        /// height shouldn't get a vote. Predictable: 2× the width is 2× the type.
        case width
        /// Height only. For a board that fills the screen vertically.
        case height
        /// The smaller of the two ratios. Guarantees nothing overflows either
        /// axis, but any window whose aspect ratio is flatter than the reference
        /// gets its type crushed by the height term — only use this when the
        /// window really does track the reference shape.
        case fit
    }

    /// The dimension the scale is derived from. Defaults to `.width`.
    public var basis: Basis
    /// The viewport the theme's size tokens were authored at.
    public var referenceViewport: Viewport
    /// Floor on the derived scale, so a small window doesn't shrink text below
    /// legibility.
    public var minimumScale: Double
    /// Ceiling on the derived scale, so a very large screen doesn't blow the
    /// type up past what reads well from across the room.
    public var maximumScale: Double

    public init(
        basis: Basis = .width,
        referenceViewport: Viewport = .reference,
        minimumScale: Double = 0.55,
        maximumScale: Double = 3
    ) {
        self.basis = basis
        self.referenceViewport = referenceViewport
        self.minimumScale = minimumScale
        self.maximumScale = maximumScale
    }

    public static let `default` = Self()

    /// Opts out of scaling: size tokens are used exactly as authored, whatever
    /// the screen. Useful for pinning a layout while designing it.
    public static let fixed = Self(minimumScale: 1, maximumScale: 1)

    /// The multiplier that maps `referenceViewport` onto `viewport`, per `basis`,
    /// clamped to `minimumScale...maximumScale`.
    ///
    /// Returns `1` for a degenerate (zero or negative) viewport — renderers do
    /// hand out `0×0` proposals during early layout passes, and those must not
    /// be mistaken for a tiny screen.
    public func scale(
        for viewport: Viewport
    ) -> Double {
        guard referenceViewport.width > 0, referenceViewport.height > 0,
              viewport.width > 0, viewport.height > 0 else {
            return 1
        }

        let widthRatio = viewport.width / referenceViewport.width
        let heightRatio = viewport.height / referenceViewport.height
        let ratio = switch basis {
        case .width: widthRatio
        case .height: heightRatio
        case .fit: min(widthRatio, heightRatio)
        }
        return min(max(ratio, minimumScale), maximumScale)
    }
}
