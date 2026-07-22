#!/usr/bin/env bash
# Cross-compile the DeskDashboard executable for the Raspberry Pi from a Mac:
# a fully-static aarch64 Linux (musl) binary that needs no Swift or libraries on
# the Pi. Prints the binary path when done.
#
# One-time setup this script assumes (see memory/pi-deployment or the repo docs):
#   1. A swift.org toolchain — NOT Xcode's, which can't drive the static SDK —
#      installed under ~/Library/Developer/Toolchains (osx .pkg,
#      `installer -target CurrentUserHomeDirectory`, no sudo).
#   2. The matching Static Linux SDK:
#      `swift sdk install <…_static-linux-….artifactbundle.tar.gz> --checksum <sum>`
#
# Override behavior with env vars:
#   CONFIG=debug            build debug instead of release
#   SWIFT_TOOLCHAIN=<path>  use a specific .xctoolchain instead of auto-detecting
#
# (The Pi now has Swift too, so `swift build -c release` natively on the Pi is an
# alternative — simpler, but much slower than cross-compiling here.)
set -euo pipefail

TARGET="aarch64-swift-linux-musl"
CONFIG="${CONFIG:-release}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Locate a swift.org toolchain -------------------------------------------
find_toolchain() {
    if [ -n "${SWIFT_TOOLCHAIN:-}" ]; then
        echo "$SWIFT_TOOLCHAIN"
        return
    fi
    # Prefer the `swift-latest` symlink, else the newest swift-*-RELEASE.
    for dir in "$HOME/Library/Developer/Toolchains" "/Library/Developer/Toolchains"; do
        [ -d "$dir" ] || continue
        if [ -d "$dir/swift-latest.xctoolchain" ]; then
            echo "$dir/swift-latest.xctoolchain"
            return
        fi
        local newest
        newest="$(ls -d "$dir"/swift-*-RELEASE.xctoolchain 2>/dev/null | sort -V | tail -1)"
        if [ -n "$newest" ]; then
            echo "$newest"
            return
        fi
    done
}

TOOLCHAIN="$(find_toolchain)"
if [ -z "$TOOLCHAIN" ] || [ ! -x "$TOOLCHAIN/usr/bin/swift" ]; then
    echo "error: no swift.org toolchain found under ~/Library/Developer/Toolchains." >&2
    echo "       Install one from https://www.swift.org/install/macos/ (Toolchain .pkg)," >&2
    echo "       or set SWIFT_TOOLCHAIN=/path/to/swift-X.Y.Z-RELEASE.xctoolchain." >&2
    exit 1
fi
SWIFT="$TOOLCHAIN/usr/bin/swift"

# --- Verify the Static Linux SDK is installed -------------------------------
if ! "$SWIFT" sdk list 2>/dev/null | grep -q "static-linux"; then
    echo "error: no Static Linux SDK installed for this toolchain." >&2
    echo "       Install it with: swift sdk install <…_static-linux-….artifactbundle.tar.gz> --checksum <sum>" >&2
    echo "       (get the URL + checksum from https://www.swift.org/install/macos/)" >&2
    exit 1
fi

# --- Build ------------------------------------------------------------------
echo "toolchain: $TOOLCHAIN"
echo "target:    $TARGET  ($CONFIG)"
cd "$REPO_ROOT"
"$SWIFT" build --product DeskDashboard --swift-sdk "$TARGET" -c "$CONFIG"

BIN="$REPO_ROOT/.build/$TARGET/$CONFIG/DeskDashboard"
echo
echo "built: $BIN"
file "$BIN"
echo
echo "To deploy: serve it from here and pull it on the Pi, e.g."
echo "  (mac) cd \"$(dirname "$BIN")\" && python3 -m http.server 8000"
echo "  (pi)  curl -O http://<this-mac-ip>:8000/DeskDashboard && chmod +x DeskDashboard && ./DeskDashboard --port 8642"
