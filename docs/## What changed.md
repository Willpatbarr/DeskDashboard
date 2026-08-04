## What changed

- Week rows are now laid out by a custom `Layout` (`MonthWeekLayout.kt`) instead of weighted
  containers (`Row` of 7 `weight(1f)` cells + a `Row` per bar lane with `weight(span)` +
  `Spacer`s, layered in a `Box` with hand-tuned top padding)
- Bars previously aligned with cells only because two weighted Rows happened to distribute
  width identically — nothing enforced it
- Cells and bars now derive edges from one pure function (`monthColumnStartX`), bar y from
  `monthBarLaneTop`; every child gets `Constraints.fixed`
- `MonthWeekBars`/`MonthBarLaneRow` deleted; naming split: `monthWeekBarPlan` = grid-level
  (columns + lanes), `monthWeekPlacementMeasurePolicy` = pixels
- Scope is per week row on purpose: weeks are geometrically independent, and the per-week
  `remember` keeps event edits row-local instead of re-laying-out all 42 cells

  ### `BoxWithConstraints` inside of `CalendarMonthView` stayed:
- `chipCapacity` (from `maxHeight/6`) decides **what gets
  composed** (chip count, "+N", displayed lanes), and composition runs before measure — a
  plain `Layout` can't feed its height back into what children exist. That requires
  subcomposition, and `BoxWithConstraints` *is* the optimized androidx tool for it
- Alternatives all lose: hand-rolled SubcomposeLayout rebuilds it; `onSizeChanged` → state is
  a frame late (flicker); screen-size-minus-chrome math recreates the "agree by hand"
  fragility this PR deletes; compose-all-place-what-fits kills "+N" (silently hidden events).
  It subcomposes once per pager page, so the cost is negligible

## Wins

- **Alignment is exact by construction** — one shared width source; the bar/cell drift bug
  class is gone
- **Placement math is unit-tested** (was untestable weight distribution): remainder-pixel
  partition, bar width == spanned cells, lane step at font scales 1.0/1.3/2.0
- **Less code** — ~40 lines of Box/Row/Spacer/weight gymnastics → one measure policy
- **Perf neutral-to-better**: emulator A/B (20-swipe fling, gfxinfo) — P50 unchanged (17ms),
  P90 34→30ms, P95 48→36ms, jank 11.3%→9.4%
- **Behavior unchanged**: pixel-identical output, taps still fall through bars to the day
  cell, pager/PTR/EventBar untouched