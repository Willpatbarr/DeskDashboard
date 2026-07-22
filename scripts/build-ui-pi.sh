#!/usr/bin/env bash
# Build the REAL SwiftCrossUI dashboard UI (`deskdashboard-ui`) natively ON the
# Raspberry Pi. Prints the binary path when done.
#
# Why native, not cross-compiled like scripts/build-pi.sh?
#   The UI uses SwiftCrossUI's GtkBackend, which links GTK 4 (dynamic C libs).
#   The static-musl SDK that build-pi.sh uses can't provide GTK, and a
#   transitive dep hard-codes `import Glibc` (fails under musl). So the UI is a
#   glibc build with GTK 4 present — see docs/ui-build-spike.md. This script
#   builds it on the Pi (which already has a Swift toolchain), which is the
#   simplest path (no custom cross SDK/sysroot to assemble).
#
# Prereqs (one-time, on the Pi):
#   sudo apt update && sudo apt install -y libgtk-4-dev clang pkg-config
#   (a Swift toolchain must already be installed and on PATH)
#
# Override behavior with env vars:
#   CONFIG=debug   build debug instead of release
set -euo pipefail

CONFIG="${CONFIG:-release}"
PRODUCT="deskdashboard-ui"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "error: $*" >&2; exit 1; }

# --- Preflight -------------------------------------------------------------
uname_s="$(uname -s)"
if [ "$uname_s" != "Linux" ]; then
    fail "this script builds the UI natively on the Pi (Linux); got $uname_s.
       On a Mac, build-pi.sh cross-compiles the dev binary, but the GTK UI
       cannot cross-compile against the static-musl SDK (see docs/ui-build-spike.md)."
fi

command -v swift >/dev/null 2>&1 \
    || fail "no 'swift' on PATH. Install a Swift toolchain for the Pi first."
command -v pkg-config >/dev/null 2>&1 \
    || fail "no 'pkg-config'. Install it: sudo apt install -y pkg-config"
command -v clang >/dev/null 2>&1 \
    || fail "no 'clang' (SwiftCrossUI's GtkBackend needs it): sudo apt install -y clang"

if ! pkg-config --exists gtk4; then
    fail "GTK 4 dev libraries not found (pkg-config gtk4).
       Install them: sudo apt install -y libgtk-4-dev clang"
fi

echo "swift:     $(command -v swift)  ($(swift --version 2>/dev/null | head -1))"
echo "gtk4:      $(pkg-config --modversion gtk4)"
echo "product:   $PRODUCT  ($CONFIG)"

# --- Build -----------------------------------------------------------------
cd "$REPO_ROOT"
swift build --product "$PRODUCT" -c "$CONFIG"

BIN="$REPO_ROOT/.build/$CONFIG/$PRODUCT"
echo
echo "built: $BIN"
file "$BIN" 2>/dev/null || true
echo
echo "Run it from inside the Pi's graphical (Wayland/X) session:"
echo "  $BIN            # ingest server on :8642 (override with --port N)"
echo
echo "Producers already POST to this Pi on :8642, so no producer changes are"
echo "needed. Fullscreen/kiosk + auto-start at boot is the appliance-hardening"
echo "step (systemd unit) in docs/next-steps.md."
