# SwiftCrossUI + static-SDK build spike

_Status as of 2026-07-22. De-risks step 1 of [next-steps.md](next-steps.md)._

## Question

Can the real UI layer (SwiftCrossUI / SwiftOpenUI) cross-compile against the
**Static Linux musl SDK** that `scripts/build-pi.sh` uses to produce the Pi
binary? This was flagged as the biggest downstream unknown.

## What was tested

A throwaway package depending on `stackotter/swift-cross-ui` @ **0.8.0** (via
its `SwiftCrossUI` + `DefaultBackend` products), built two ways with the
swift.org 6.3.3 toolchain:

1. **macOS host** (`swift build`) — AppKit backend.
2. **Static musl aarch64** (`swift build --swift-sdk aarch64-swift-linux-musl`)
   — the Pi cross-compile path.

## Findings

| Path | Result |
|------|--------|
| Dependency resolution | ✅ resolves cleanly (SwiftCrossUI + swift-syntax, image-formats, argument-parser, …) |
| macOS host / AppKit | ✅ **builds & links** (~83 s) |
| Static musl aarch64 (Pi) | ❌ **fails to compile** |

### Why the static-musl build fails

Two independent blockers, one immediate, one fundamental:

1. **Immediate:** a transitive dependency, `stackotter/jpeg` (pulled in by
   `swift-image-formats`, which SwiftCrossUI uses for image loading), hard-codes
   `#elseif os(Linux) import Glibc`. Under the static-linux SDK the C module is
   **`Musl`, not `Glibc`**, so it errors with `no such module 'Glibc'`. This is
   the same portability issue we fixed in our own `DevHTTPServer` (which now
   imports `Musl`) — but here it's in **third-party code we don't control**.

2. **Fundamental:** SwiftCrossUI's Linux backend is **GtkBackend**, which needs
   **GTK 4 system libraries** (dynamic C libraries) plus `clang`. The whole
   point of the static-musl build is a *self-contained* binary with no libs on
   the Pi — you cannot statically bundle GTK, and the musl SDK sysroot has no
   aarch64 GTK to link against. Even with the jpeg issue patched, the GTK link
   would not be satisfiable on this SDK.

**Conclusion: the static-musl path (`build-pi.sh`) cannot build the real UI.**
That path stays as-is for the dev `DeskDashboard` binary; the UI needs a
different toolchain.

## Recommendation

Build the real UI as a **glibc dynamic binary with GTK 4 present on the Pi**:

- **Option A — build natively on the Pi** (recommended first step). The Pi
  already has a Swift toolchain; `sudo apt install libgtk-4-dev clang`, then
  `swift build -c release --product deskdashboard-ui` on the Pi. Simplest, no
  SDK plumbing; slower compiles (SwiftCrossUI + swift-syntax macros are heavy).
- **Option B — cross-compile from the Mac with a glibc Swift SDK** (Debian/Ubuntu
  aarch64) that has GTK 4 in its sysroot. Faster iteration, more one-time setup.
  Both jpeg's `Glibc` import and the GTK link resolve on a glibc target.

Because of this split, the UI is a **separate SwiftPM product** (`deskdashboard-ui`)
from `DeskDashboard`. `build-pi.sh` builds `--product DeskDashboard` only, so the
musl build never pulls SwiftCrossUI and keeps working unchanged.

## Note on "SwiftOpenUI"

SwiftCrossUI (stackotter) is the concrete, working framework used here; its
`DefaultBackend` gives AppKit on macOS and GTK on Linux with the same view code.
The same GTK-vs-static-musl conclusion applies to any GTK-backed Swift UI on the
Pi — the constraint is GTK's dynamic C libraries, not the specific wrapper.
