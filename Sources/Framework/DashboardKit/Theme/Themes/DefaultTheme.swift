// DefaultTheme.swift — Theme: the framework baseline, owning the `.default` token values.

// The default theme: the `.default` token values every other theme falls back
// to, plus a theme that takes all of them.
//
// These are the values behind `Theme`'s protocol-extension defaults, so editing
// this file moves every theme that hasn't named its own — which is exactly why
// they live in one visible place rather than inline in the scaffold.
//
// Sizes here are *reference* sizes, authored at `ThemeMetrics.referenceViewport`
// and scaled to the screen by `Theme.sizes(for:)` — not fixed pixel values.

public extension ThemeTypography {
    static let `default` = Self(
        fontFamily: "system-ui",
        headingSize: 28,
        bodySize: 17,
        captionSize: 13,
        headingWeight: 700,
        bodyWeight: 500
    )
}

public extension ThemeSpacing {
    static let `default` = Self(
        widgetGap: 12,
        tilePadding: 16,
        sectionMargin: 20
    )
}

public extension ThemeShape {
    static let `default` = Self(
        cornerRadius: 8,
        borderWidth: 1,
        elevation: 2
    )
}

public extension ThemeAnimation {
    static let `default` = Self(
        transitionDuration: 0.18,
        easing: "easeInOut"
    )
}

/// Every token at its default. Equivalent to the smallest possible conformance
/// (`struct T: Theme { let name = "T" }`), named so that "I want the framework
/// baseline" can be said explicitly.
///
/// Colours come from `.darkDesk` — the baseline palette, declared with the
/// baseline theme in `DarkDeskTheme.swift` rather than duplicated here.
public struct DefaultTheme: Theme, Sendable {
    public let name = "Default"

    public init() {}
}
