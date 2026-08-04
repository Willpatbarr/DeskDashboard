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
# Building SwiftCrossUI + swift-syntax macros is memory-hungry. On a Pi this can
# exhaust RAM and hard-crash the box (OOM), with peak usage at the end (optimize
# + link). To avoid that, this script caps compiler parallelism based on RAM
# (~2 GB/job) and silences the swift-backtrace mprotect warnings. A `release`
# build is much heavier than `debug`; use `CONFIG=debug` for a lower-memory first
# build.
#
# Override behavior with env vars:
#   CONFIG=debug   build debug instead of release (lighter; recommended first)
#   JOBS=N         force N parallel compiler jobs (default: RAM-based, >=1)
set -euo pipefail

# Silence "unable to protect path to swift-backtrace ... disabling backtracing"
# noise (harmless; the crash backtracer can't mprotect under memory pressure).
export SWIFT_BACKTRACE="${SWIFT_BACKTRACE:-enable=no}"

CONFIG="${CONFIG:-release}"
PRODUCT="deskdashboard-ui"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pick a safe job count: ~2 GB of RAM per compiler job, capped at core count,
# floor of 1. Override with JOBS=N.
compute_jobs() {
    if [ -n "${JOBS:-}" ]; then echo "$JOBS"; return; fi
    local cores mem_kb mem_jobs
    cores="$(nproc 2>/dev/null || echo 1)"
    mem_kb="$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    mem_jobs=$(( mem_kb / 2000000 ))          # ~2 GB per job
    [ "$mem_jobs" -lt 1 ] && mem_jobs=1
    if [ "$mem_jobs" -lt "$cores" ]; then echo "$mem_jobs"; else echo "$cores"; fi
}
JOBS="$(compute_jobs)"

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
echo "product:   $PRODUCT  ($CONFIG, -j $JOBS)"

# --- Build -----------------------------------------------------------------
cd "$REPO_ROOT"
swift build --product "$PRODUCT" -c "$CONFIG" -j "$JOBS"

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
