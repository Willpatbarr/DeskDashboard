// TileView.swift — Tile chrome plus the dispatcher that interprets a `WidgetView` tree into views.

import DashboardKit
import SwiftCrossUI

/// Renders one widget tile by interpreting a `WidgetView` tree into SwiftCrossUI
/// views. The tree comes from the widget's chosen `WidgetLayout`; this view owns
/// the *look* — it resolves each `TextRole` to a concrete font + color from the
/// theme `palette`, and wraps the content in the tile chrome (padding, surface,
/// corner radius).
///
/// This file is the chrome plus the dispatcher. The node renderers with real
/// geometry in them live alongside it:
/// - `TileView+DisplayText.swift` — the tracked `.display` run
/// - `TileView+FittedText.swift` — the self-sizing value
/// - `TileView+Transport.swift` — progress line, play/pause
/// - `TextRoleToSCUIStyle.swift` — role → concrete type (on `ThemeToSCUIPalette`)
/// - `TransportGlyphs.swift` — the glyph paths
///
/// They're methods on `TileView` rather than separate `View` types on purpose:
/// wrapping a node in another view changes the view-graph shape, and this backend
/// has twice produced blank or collapsed output from exactly that kind of change.
struct TileView: View {
    let snapshot: AttachedWidgetSnapshot
    let palette: ThemeToSCUIPalette
    /// When set (preview mode), forces this layout on every tile; otherwise the
    /// widget's own `configuration.layout` is used.
    var layoutOverride: WidgetLayout? = nil
    /// Drops the tile chrome (surface + corners) for this render, regardless of
    /// the widget's own `isContainerless` — a board-level override, like
    /// `layoutOverride`.
    var containerless: Bool = false
    /// Drops the tile's inner padding (set by a `flush` board column) so the
    /// layout's content reaches the tile bounds — for layouts drawing their own
    /// cards. Values only, never structure, same rule as `containerless`.
    var flush: Bool = false
    /// Suppresses the widget's title label for this render (a board-level
    /// choice — every layout already omits an absent title).
    var hidesTitle: Bool = false
    /// Which edge this tile's contents line up on, or `nil` for "as the layout
    /// draws it". Applied by the interpreter to every vertical run, so it works
    /// for every layout without any of them knowing about it — see `TileAlignment`.
    ///
    /// Optional rather than defaulting to `.leading` because the default is
    /// per-NODE, not per-tile: a `.centered` group and a `.fittedText` value
    /// centre themselves (that is what those nodes are for), while an ordinary
    /// stack runs leading. Forcing one tile-wide default shoved the focus board's
    /// full-width clock into the left margin.
    var alignment: TileAlignment? = nil

    /// The alignment for an ordinary run: what was chosen, else leading.
    var runAlignment: TileAlignment { alignment ?? .leading }
    /// The alignment for a node that centres itself by default (`.centered`,
    /// `.fittedText`): what was chosen, else centre.
    var centredAlignment: TileAlignment { alignment ?? .center }

    /// Centres the content in the tile's height instead of pinning it to the top.
    ///
    /// For a tile much SHORTER than usual: the focus board's bottom strip is one
    /// line of text in ~69px, and top-aligned that line sat ~5px above the tile's
    /// centre with all the slack below it.
    var centersVertically: Bool = false
    /// Sizes the tile to its content's width instead of filling the space offered.
    /// Set by a `hugsContent` board column — the tile itself has to stop being
    /// greedy, or the column's own intrinsic width means nothing.
    var hugsWidth: Bool = false
    /// Raised when a `.tappable` node in this tile is tapped or held: the action
    /// name, plus whether it came from a hold. The caller pairs it with the widget
    /// id and routes it onward; this view deliberately knows nothing about the
    /// framework side.
    /// `(action, cameFromHold, isHoldable, holdRepeats)`. The last flag only
    /// means anything when `cameFromHold` is set: a hold that OPENS something
    /// must not repeat — see `HoldAction`.
    var onAction: ((String, Bool, Bool, Bool) -> Void)? = nil
    /// Raised when a press on a hold-capable region ends, so a repeating hold can
    /// stop. Separate from `onAction` because it carries no action of its own.
    var onPressEnded: (() -> Void)? = nil

    /// Semantic content for the layout: real content when present, otherwise the
    /// configured title + a placeholder so an unrendered tile isn't blank.
    ///
    /// Not private: `BoardScreen` needs the same resolved content to estimate a
    /// content-hugging column's width, and resolving it twice by hand would be two
    /// places to keep in step.
    var layoutContent: WidgetContent {
        WidgetContent(
            title: hidesTitle ? nil : (snapshot.content?.title ?? snapshot.configuration.title),
            primaryText: snapshot.content?.primaryText ?? "…",
            secondaryText: snapshot.content?.secondaryText,
            accessoryText: snapshot.content?.accessoryText,
            progress: snapshot.content?.progress,
            elapsedText: snapshot.content?.elapsedText,
            durationText: snapshot.content?.durationText,
            isPlaying: snapshot.content?.isPlaying,
            metadata: snapshot.content?.metadata ?? []
        )
    }

    var body: some View {
        let layout = layoutOverride ?? snapshot.configuration.layout
        // Containerless switches VALUES only (clear surface, square corners) —
        // never the modifier chain. Branching the view structure here blanked
        // every board on the panel, and a chrome-less tile still needs the
        // background wrapper anyway: a stack with no background reports no size
        // on the GTK backend.
        let plain = containerless || snapshot.configuration.isContainerless
        return interpret(layout.makeView(layoutContent))
            .padding(.horizontal, flush ? 0 : palette.tilePadding)
            .padding(.vertical, flush ? 0 : palette.verticalTilePadding)
            .frame(
                maxWidth: hugsWidth ? nil : .infinity,
                maxHeight: .infinity,
                alignment: runAlignment.aligned(centeredVertically: centersVertically)
            )
            .background(plain ? Color.clear : palette.surface)
            .cornerRadius(plain ? 0 : Int(palette.cornerRadius.rounded()))
        // The outline is NOT applied here — see `tileBorder` in `TileCorners.swift`.
        // Chrome composited inside a child view's own body doesn't take on this
        // backend; an `.overlay` here blanked every tile on the board.
    }

    // MARK: - Colour tokens

    /// A layout's `ColorToken` as a concrete colour from this tile's palette.
    private func resolve(_ token: ColorToken) -> Color? {
        switch token {
        case .background: palette.background
        case .surface: palette.surface
        case .surfaceRaised: palette.surfaceRaised
        case .text: palette.text
        case .muted: palette.muted
        case .secondary: palette.secondary
        case .accent: palette.accent
        case .divider: palette.divider
        case .border: palette.border ?? palette.divider
        case let .hex(value): Color(hex: value)
        }
    }

    /// The same, as a hex string — GTK CSS (the card outline and its leading
    /// accent) is written as text, not as a `Color`.
    private func resolveHex(_ token: ColorToken) -> String? {
        let colors = palette.sourceColors
        return switch token {
        case let .hex(value): value
        case .background: colors.background
        case .surface: colors.surface
        case .surfaceRaised: colors.surfaceRaised.isEmpty ? colors.surface : colors.surfaceRaised
        case .text: colors.text
        case .muted: colors.mutedText
        case .secondary: colors.secondary
        case .accent: colors.accent
        case .divider: colors.divider
        case .border: colors.border.isEmpty ? colors.divider : colors.border
        }
    }

    // MARK: - Interpreter (WidgetView -> SwiftCrossUI)

    /// - Parameter insideScroll: true once the walk has descended into a
    ///   `.scroll`. Taps there fire on RELEASE with drag slop instead of on
    ///   press, or every scroll gesture would activate the card it started on —
    ///   see `tapUnlessDragged`. Threaded rather than global so the MTG tiles,
    ///   whose hold/tap arbitration is tuned around press-to-fire, are untouched.
    private func interpret(_ node: WidgetView, insideScroll: Bool = false) -> AnyView {
        switch node {
        case let .text(string, role):
            let style = palette.style(for: role)
            let text = style.uppercased ? string.uppercased() : string
            // Note: do NOT try to lift display text with a shorter `.frame(height:)`.
            // A frame smaller than the label's natural box does not centre the text
            // here — it pushes the glyphs *down* and out of their box, so the
            // supporting line gets drawn straight through them (verified on the
            // panel twice now).
            if role == .display {
                return AnyView(tightenedText(text, style: style))
            }
            return AnyView(
                Text(text)
                    .font(.system(size: style.size, weight: style.weight))
                    .foregroundColor(style.color)
            )

        case let .badge(string):
            return AnyView(
                Text(string)
                    .font(.system(size: palette.captionSize, weight: .bold))
                    .foregroundColor(palette.accent)
            )

        case let .coloredText(string, role, token):
            // `.text` with the colour overridden by data — size and weight still
            // come from the role, so it scales with the panel.
            let style = palette.style(for: role)
            let text = style.uppercased ? string.uppercased() : string
            return AnyView(
                Text(text)
                    .font(.system(size: style.size, weight: style.weight))
                    .foregroundColor(resolve(token) ?? style.color)
            )

        case let .scroll(fade, child):
            // Vertical only: a horizontal scroll inside a column would fight
            // the board's own left-right taps. The height comes from the frame
            // this is given — see the node's doc for why that is required.
            if let hex = fade.flatMap(resolveHex) {
                // Display-wide and idempotent — see `ScrollFade`.
                ScrollFade.install(hex: hex, height: 20 * palette.scale)
            }
            return AnyView(
                ScrollView(.vertical) {
                    interpret(child, insideScroll: true)
                }
            )

        case let .columns(spacing, children):
            // Equal split, stated explicitly: measure the row and give every
            // child the same slice. Same GeometryReader pattern (and the same
            // not-yet-measured guard) as the transport progress bar.
            let gap = spacing * palette.scale
            let count = max(1, children.count)
            return AnyView(
                GeometryReader { proxy in
                    let raw = proxy.size.width
                    let width = raw.isFinite ? max(0, raw) : 0
                    let slice = max(1, (width - gap * Double(count - 1)) / Double(count))
                    let rawHeight = proxy.size.height
                    // A DEFINITE height, passed down so a `.scroll` inside a
                    // column has something to clip against; without it the
                    // scroll container grows to its content instead.
                    let height = rawHeight.isFinite && rawHeight > 0 ? rawHeight.rounded() : nil
                    HStack(spacing: Int(gap.rounded())) {
                        ForEach(Array(children.enumerated()), id: \.offset) { item in
                            interpret(item.element, insideScroll: insideScroll)
                                .frame(width: slice.rounded(), height: height)
                        }
                    }
                }
            )

        case let .card(style, child):
            // The `.padding` / `.background` / `.cornerRadius` chain is the same
            // ceremony the tile chrome itself uses — a stack with no background
            // reports no size on the GTK backend.
            let pad = max(0, Int((style.padding * palette.scale).rounded()))
            let radius = max(0, Int((style.cornerRadius * palette.scale).rounded()))
            let accent = style.accent.flatMap(resolveHex).map {
                (hex: $0, width: style.accentWidth * palette.scale)
            }
            return AnyView(
                interpret(child, insideScroll: insideScroll)
                    .padding(pad)
                    .frame(
                        maxWidth: .infinity,
                        alignment: runAlignment.aligned(centeredVertically: false)
                    )
                    .background(resolve(style.fill) ?? palette.surface)
                    .cornerRadius(radius)
                    // Always called, nil writes "none" — widgets are reused
                    // across re-renders (see `cssBorder`'s own note).
                    .cssBorder(
                        hex: style.border.flatMap(resolveHex),
                        width: 1,
                        radius: Double(radius),
                        leadingAccent: accent
                    )
            )

        case .spacer:
            return AnyView(Spacer(minLength: 0))

        case let .tappable(action, hold, child):
            // The child draws exactly as it would untapped; only gestures are
            // added. A renderer with no input story could ignore the wrapper
            // entirely and still produce correct pixels.
            //
            // Both gestures land on the same view. SwiftCrossUI only warns that a
            // gesture displaces *the same kind* within a view, so a primary tap and
            // a long press coexist — GTK backs them with separate GestureClick and
            // GestureLongPress controllers.
            // A region with a hold reports `isHoldable` on its taps too, so the
            // gate knows to wait and see rather than emitting immediately.
            let isHoldable = hold != nil
            let slop = 12 * palette.scale
            if insideScroll, hold == nil {
                // Still `onTapGesture` first: that is what attaches the
                // GestureClick which `tapUnlessDragged` then re-points at
                // release. Slop scales with the panel like every other size.
                //
                // The real action goes in BOTH places, and it cannot
                // double-fire: on GTK `tapUnlessDragged` REPLACES the
                // `pressed`/`released` handlers SwiftCrossUI installed, so only
                // its own release path survives.
                //
                // Off GTK the modifier is a no-op, so this closure is the only
                // delivery there — it used to be empty, which was simply wrong.
                // It is still not enough to make a card tappable on the AppKit
                // dev build: measured there, a primary tap inside a `ScrollView`
                // never reaches the gesture at all (the long press does), so a
                // card tap has to be verified on the panel. Correct anyway, and
                // the arm below depends on it.
                return AnyView(
                    interpret(child, insideScroll: true)
                        .onTapGesture { onAction?(action, false, false, true) }
                        .tapUnlessDragged(slop: slop) {
                            onAction?(action, false, false, true)
                        }
                )
            }
            if insideScroll, let hold {
                // A card that BOTH scroll-arbitrates its tap and recognises a
                // long press — the session board's cards, since the detail
                // panel landed.
                //
                // The ordering hazard is real and is why this doesn't just
                // combine the two arms: `tapUnlessDragged` fires the tap from
                // GTK's `released`, and `onPressRelease` fires `pressEnded`
                // from that same signal, so which one `HoldGate` sees first is
                // not determined. Left to the gate's echo window, a long press
                // would ALSO focus the session about half a second later.
                // `tapUnlessDraggedOrHeld` settles it locally instead: the box
                // that owns the press knows it turned into a hold and simply
                // doesn't fire the tap.
                let ended = onPressEnded
                return AnyView(
                    interpret(child, insideScroll: true)
                        // `isHoldable: true` — off GTK this is the only tap
                        // delivery, and the gate has to withhold it until the
                        // press resolves or a long press would focus as well as
                        // open. On GTK it is replaced outright (see above).
                        .onTapGesture { onAction?(action, false, true, true) }
                        .onTapGesture(gesture: .longPress) {
                            onAction?(hold.action, true, true, hold.repeats)
                        }
                        // `onPressRelease` is NOT chained here: it claims the
                        // same `GestureClick.released` this modifier fires the
                        // tap from, and would overwrite it. The callback is
                        // handed over instead.
                        .tapUnlessDraggedOrHeld(
                            slop: slop,
                            onHold: { onAction?(hold.action, true, true, hold.repeats) },
                            // Already arbitrated by the box, so this is a plain
                            // tap — `isHoldable: false`, no need to defer it a
                            // second time inside the gate.
                            onTap: { onAction?(action, false, false, true) },
                            onRelease: { ended?() }
                        )
                )
            }
            let tappable = interpret(child, insideScroll: insideScroll)
                .onTapGesture { onAction?(action, false, isHoldable, true) }
            guard let hold else { return AnyView(tappable) }
            let ended = onPressEnded
            return AnyView(
                tappable
                    .onTapGesture(gesture: .longPress) {
                        onAction?(hold.action, true, true, hold.repeats)
                    }
                    // Release ends the repeat. GTK only; see `PressReleaseGTK`.
                    .onPressRelease { ended?() }
            )

        case let .layered(base, _, _, _):
            // Only the BASE is drawn here. The scrim and the panel are lifted to
            // the root view (see `DashboardRootView.modal`) so they cover the
            // shell's chrome — the fullscreen rail — as well as this tile.
            // Dimming only the tile that raised the modal left the rail bright
            // beside a greyed board, which reads as a half-finished render.
            //
            // The node still carries them because the WIDGET is what knows a
            // panel is open; the root reads them back out of this same tree.
            return interpret(base, insideScroll: insideScroll)

        case let .centered(children):
            let views = children.map { interpret($0, insideScroll: insideScroll) }
            let indexed = Array(views.enumerated())

            let largest = children.reduce(0.0) { widest, child in
                if case let .text(_, role) = child {
                    return max(widest, palette.style(for: role).size)
                }
                return widest
            }

            // Lift the group by the ascent its FIRST line reserves above its cap
            // height (~0.17× the font size), so a big value's glyph top lines up with
            // the smaller values in neighbouring tiles instead of sitting lower.
            //
            // First line, not the largest: the lift cancels the gap above the group's
            // top edge, which only the top line contributes. Sizing it from the
            // largest was equivalent while the value always came first — but with
            // `centeredValue(subtitle: .above)` the group starts with a subtitle, and
            // a display-sized 20px lift dragged it clean off the top of the tile
            // (measured on the panel: the date rendered 13px tall instead of 26).
            let leadingSize = children.lazy.compactMap { child -> Double? in
                if case let .text(_, role) = child { return palette.style(for: role).size }
                return nil
            }.first ?? 0
            let lift = Int((leadingSize * 0.11).rounded())

            // Fast path: one child, nothing to lift. The stack below exists to space
            // and align SIBLINGS, and a lone child has none — but SwiftCrossUI still
            // pays for the whole VStack + ForEach subtree on every layout pass, and
            // `computeStackLayout` is the hottest frame in a profile of this app.
            // Most `.centered` uses in `lifeCounter` are a single `.tappable`, whose
            // `leadingSize` is 0, so they land here.
            if views.count == 1, lift == 0 {
                return AnyView(views[0].frame(maxWidth: .infinity, alignment: centredAlignment.topAligned))
            }

            return AnyView(
                // Negative, because the two labels' own boxes already leave ~50px
                // between the inks at this size; this trims it to ~44px. (−0.13 /
                // ~26px read too tight under the single-run tracked clock —
                // measured 27px ink gap on the panel, 2026-08-04.)
                // `.centered` names the layout's INTENT (a value group that owns
                // its tile), not a hard-coded centre — an edited tile aligns its
                // group like any other run.
                VStack(alignment: centredAlignment.horizontal, spacing: Int((largest * -0.03).rounded())) {
                    ForEach(indexed, id: \.offset) { $0.element }
                }
                .frame(maxWidth: .infinity, alignment: centredAlignment.topAligned)
                .padding(.top, -lift)
            )

        case .divider:
            // An empty stack WITH a background, the same shape `progressBar` uses:
            // a bare stack reports no size on this backend and vanishes, but one
            // carrying a background and an explicit height is a reliable rule.
            // Height is pinned top and bottom so it can't be stretched by a
            // greedy sibling — a rule that grows into a slab is a memorable bug.
            // A hairline is a hairline: 1px, NOT scaled by the type scale. Scaling
            // it rounded to 2px on the panel at 1.5×, which reads as a divider bar
            // rather than a rule and sat heavier than the 1px tile outline it lines
            // up with. Sizes here normally scale; this one is a device pixel.
            let rule = 1.0
            return AnyView(
                HStack(spacing: 0) {}
                    .frame(maxWidth: .infinity, minHeight: rule, maxHeight: rule)
                    .background(palette.divider)
            )

        case let .progressBar(fraction):
            return AnyView(progressBar(fraction: fraction))

        case let .fittedText(string):
            return AnyView(fittedText(string))

        case let .playState(playing):
            return AnyView(playState(playing: playing))

        case let .region(minWidth, minHeight, child):
            // Authored against the reference canvas, so scale like every other size.
            let minW = minWidth * palette.scale
            let minH = minHeight * palette.scale
            return AnyView(
                interpret(child, insideScroll: insideScroll).frame(
                    minWidth: minW > 0 ? minW : nil,
                    minHeight: minH > 0 ? minH : nil
                )
            )

        case let .stack(axis, spacing, children):
            let views = children.map { interpret($0, insideScroll: insideScroll) }
            let indexed = Array(views.enumerated())
            // Layout spacings are authored against the theme's reference canvas
            // like every other size, so scale them with the palette.
            let gap = Int((spacing * palette.scale).rounded())
            switch axis {
            case .vertical:
                return AnyView(
                    VStack(alignment: runAlignment.horizontal, spacing: gap) {
                        ForEach(indexed, id: \.offset) { $0.element }
                    }
                    .frame(maxWidth: .infinity, alignment: runAlignment.topAligned)
                )
            case .horizontal:
                // No per-child baseline correction here. Mixed type sizes on one
                // line were nudged onto a shared BASELINE for a while, which is
                // typographically conventional but reads as misaligned in a short
                // tile: what the eye centres on is each run's ink, and the stack
                // already lines up ink centres to within a pixel on its own
                // (measured: label centre 392.5 against value centre 391.5). Two
                // sizes can share a baseline or a centre, not both — this board
                // wants centres.
                return AnyView(
                    HStack(spacing: gap) {
                        ForEach(indexed, id: \.offset) { $0.element }
                    }
                )
            }
        }
    }
}
