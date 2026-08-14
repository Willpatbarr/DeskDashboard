// HueMode.swift — Header toggle state: which colour variant the whole UI wears.

import DashboardKit

/// A colour variant the UI can be switched to live, from the header.
///
/// Each case carries a whole palette rather than a hue angle. Rotating the green
/// theme's hue was the first attempt and it is not what these variants are: they
/// were designed one at a time and don't agree about their dark ends, so no single
/// rotation produces all four. Each is stated instead.
///
/// `.original` carries no palette at all, which is different from carrying the
/// green one: it means "leave the arrangement's own theme alone", so switching to
/// it restores whatever a board authored, gradients included.
///
/// **Pill fills are sampled** from the reference mock-ups.
///
/// **The dark ends are not.** Sampled straight, blue sat on a 0.80-saturation navy
/// and plum on a 0.32 aubergine, and a blue label on a blue field has nothing like
/// the contrast of amber's gold on its near-neutral black. Amber was the one that
/// worked, so its structure is the rule now: every variant takes amber's exact
/// background and surface lightness, at a saturation of 0.10 rather than a full
/// wash. Each variant is then carried by its accent instead of by its background.
///
/// **Label and rule colours are derived.** The text in the mock-ups is small and
/// heavily antialiased — sampling it returned the rule underneath or white bleed
/// from the numerals, never a true value — so each variant takes its hue from its
/// own accent and its lightness and saturation from the green board. That keeps all
/// five reading with the same weight.
///
/// `.slate` is the exception to "each is carried by its accent": it is the same
/// structure at saturation ZERO, for wearing over a wallpaper. A photo brings its
/// own hues and a tinted panel either agrees with them or fights them, board by
/// board — a neutral one does neither. It's the only variant that authors an alpha
/// on its surface (see `colors`).
enum HueMode: CaseIterable {
    case original
    case teal
    case blue
    case plum
    case amber
    case slate

    /// Switcher labels — kept to ≤5 characters, as the pill sizes every slot to the
    /// widest one and the header already carries two other pills.
    var label: String {
        switch self {
        case .original: "Green"
        case .teal: "Teal"
        case .blue: "Blue"
        case .plum: "Plum"
        case .amber: "Amber"
        case .slate: "Slate"
        }
    }

    /// The palette to draw in, or `nil` to leave the arrangement's theme alone.
    ///
    /// Every variant is flat — no `backgroundGradient` — because the mock-ups are.
    /// Selecting one therefore flattens a gradient theme (MTG) for as long as it's
    /// selected; `.original` puts it back.
    ///
    /// `border` values look brighter than the outline they draw ON PURPOSE. A 1px
    /// stroke is antialiased and only ~68% covers its pixel, so it blends with the
    /// background behind it — each of these is the value that *renders* the intended
    /// hairline over that variant's own background. See `RuledGreenTheme`.
    var colors: ThemeColors? {
        switch self {
        case .original:
            nil
        case .teal:
            ThemeColors(
                background: "#01151C", surface: "#0A2A31", primary: "#FFFFFF",
                secondary: "#99D1CE", accent: "#A4ECE8", text: "#FFFFFF",
                mutedText: "#99D1CE", divider: "#99D1CE", border: "#3F6761"
            )
        case .blue:
            ThemeColors(
                background: "#0E1012", surface: "#191C1F", primary: "#FFFFFF",
                secondary: "#99BFD1", accent: "#77CCF5", text: "#FFFFFF",
                mutedText: "#99BFD1", divider: "#99BFD1", border: "#3F6475"
            )
        case .plum:
            ThemeColors(
                background: "#100E12", surface: "#1C191F", primary: "#FFFFFF",
                secondary: "#B899D1", accent: "#CFAAED", text: "#FFFFFF",
                mutedText: "#B899D1", divider: "#B899D1", border: "#5D3F75"
            )
        case .amber:
            ThemeColors(
                background: "#101010", surface: "#1C1C1C", primary: "#FFFFFF",
                secondary: "#D1BA99", accent: "#D7AC6D", text: "#FFFFFF",
                mutedText: "#D1BA99", divider: "#D1BA99", border: "#675337"
            )
        case .slate:
            // Amber's lightness at almost no saturation, so it sits in the same
            // family as the other four. Not a dead neutral: every value leans
            // ~16/255 blue over red, with green halfway, which is enough to read
            // as cool without becoming the blue variant. The pairs below are
            // luminance-matched to the flat greys they replaced (each within ~1
            // of its old Rec.601 value), so this is a hue shift only — nothing
            // here got lighter or darker.
            //
            // The surface carries an alpha the others don't: 0xD9 ≈ 0.85. Over a
            // wallpaper that COMPOUNDS with the 0.55 the model already applies
            // (`Color.opacity` multiplies), landing near 0.47 — thinner than any
            // other variant, which is the point of this one. With the wallpaper
            // off it merely darkens the surface toward the background by a shade.
            ThemeColors(
                background: "#0F1013", surface: "#1A1C20D9", primary: "#FFFFFF",
                secondary: "#B3BAC5", accent: "#C6CDD8", text: "#FFFFFF",
                mutedText: "#B3BAC5", divider: "#B3BAC5", border: "#535A63"
            )
        }
    }
}
