import SwiftCrossUI

/// The interactive "MTG mode" screen, modeled on the reference HTML: four
/// tappable life counters flanking a center stack (a live mini-clock over a
/// turn counter).
///
/// Each counter owns its own local `@State`, so state persists across the
/// per-tick re-renders (the mini-clock updating doesn't reset the life totals)
/// but is ephemeral — leaving and re-entering the mode starts a fresh game.
struct MTGModeView: View {
    let palette: ThemePalette
    /// Live time text from the clock widget, shown in the mini-clock.
    let time: String

    var body: some View {
        HStack(spacing: palette.widgetGap) {
            LifeCounterView(palette: palette).tileCorners(palette)
            LifeCounterView(palette: palette).tileCorners(palette)
            centerStack
            LifeCounterView(palette: palette).tileCorners(palette)
            LifeCounterView(palette: palette).tileCorners(palette)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var centerStack: some View {
        VStack(spacing: palette.verticalWidgetGap) {
            MiniClockView(palette: palette, time: time).tileCorners(palette)
            TurnCounterView(palette: palette).tileCorners(palette)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Life counter

/// One player's life total: tap `+`/`−` to adjust, tap the total to reset to 40.
private struct LifeCounterView: View {
    let palette: ThemePalette
    @State private var life = 40

    var body: some View {
        VStack(spacing: 0) {
            tapGlyph("+") { life += 1 }
            Spacer(minLength: 0)
            Text("\(life)")
                .font(.system(size: palette.headingSize * 1.8, weight: palette.headingWeight))
                .foregroundColor(palette.primary)
                .onTapGesture { life = 40 }
            Spacer(minLength: 0)
            tapGlyph("−") { life -= 1 }
        }
        .padding(.horizontal, palette.tilePadding)
        .padding(.vertical, palette.verticalTilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface)
        .cornerRadius(Int(palette.cornerRadius.rounded()))
    }

    /// A large, tappable `+`/`−` glyph in the accent color. Sized off the
    /// palette's heading size so the tap targets grow with the screen.
    private func tapGlyph(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Text(symbol)
            .font(.system(size: palette.headingSize, weight: .light))
            .foregroundColor(palette.accent)
            .padding(.horizontal, Int((8 * palette.scale).rounded()))
            .padding(.vertical, max(2, Int((8 * palette.verticalScale).rounded())))
            .onTapGesture(perform: action)
    }
}

// MARK: - Turn counter

/// The shared turn number: tap the number to advance, tap RESET to zero it.
private struct TurnCounterView: View {
    let palette: ThemePalette
    @State private var turn = 0

    var body: some View {
        VStack(spacing: max(2, Int((4 * palette.verticalScale).rounded()))) {
            Text("TURN")
                .font(.system(size: palette.captionSize, weight: palette.bodyWeight))
                .foregroundColor(palette.accent)
            Spacer(minLength: 0)
            Text("\(turn)")
                .font(.system(size: palette.headingSize * 2.6, weight: palette.headingWeight))
                .foregroundColor(palette.primary)
                .onTapGesture { turn += 1 }
            Spacer(minLength: 0)
            if turn >= 1 {
                Text("RESET")
                    .font(.system(size: palette.captionSize, weight: .semibold))
                    .foregroundColor(palette.accent)
                    .onTapGesture { turn = 0 }
            }
        }
        .padding(.horizontal, palette.tilePadding)
        .padding(.vertical, palette.verticalTilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface)
        .cornerRadius(Int(palette.cornerRadius.rounded()))
    }
}

// MARK: - Mini clock

/// A compact clock panel showing the live time in the accent color.
private struct MiniClockView: View {
    let palette: ThemePalette
    let time: String

    var body: some View {
        Text(time)
            .font(.system(size: palette.headingSize, weight: palette.headingWeight))
            .foregroundColor(palette.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.surface)
            .cornerRadius(Int(palette.cornerRadius.rounded()))
    }
}
