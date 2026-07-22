#!/usr/bin/env bash
# Install/reload the DeskDashboard now-playing LaunchAgent on this machine.
# Figures out the correct absolute paths (repo, atvscript, python) for whatever
# user/host it runs on, writes the plist, and loads it. Safe to re-run.
#
# Prereq: pyatv installed. On Homebrew Python (externally-managed) use pipx:
#   brew install pipx && pipx ensurepath && pipx install pyatv
#
# Override before running if needed:
#   DD_ATV_ID=<homepod id>  DD_INGEST_URL=http://host:8642/ingest/now-playing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRODUCER="$SCRIPT_DIR/now-playing-push.py"

# Locate atvscript: PATH, then pipx's bin dir, then pip --user locations.
ATVSCRIPT="$(command -v atvscript || true)"
if [ -z "$ATVSCRIPT" ]; then
    for candidate in "$HOME/.local/bin/atvscript" "$HOME"/Library/Python/*/bin/atvscript; do
        [ -x "$candidate" ] && ATVSCRIPT="$candidate" && break
    done
fi
if [ -z "$ATVSCRIPT" ]; then
    echo "atvscript not found. Install pyatv first:" >&2
    echo "  brew install pipx && pipx ensurepath && pipx install pyatv" >&2
    exit 1
fi

PYTHON="$(command -v python3)"
ATV_ID="${DD_ATV_ID:-B2C043882063}"
INGEST_URL="${DD_INGEST_URL:-http://127.0.0.1:8642/ingest/now-playing}"
LABEL="com.willbarr.deskdashboard.nowplayingpush"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON</string>
        <string>$PRODUCER</string>
    </array>
    <key>StartInterval</key>
    <integer>5</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>DD_ATV_ID</key>
        <string>$ATV_ID</string>
        <key>DD_INGEST_URL</key>
        <string>$INGEST_URL</string>
        <key>DD_ATVSCRIPT</key>
        <string>$ATVSCRIPT</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/deskdashboard-nowplaying.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/deskdashboard-nowplaying.err</string>
</dict>
</plist>
PLIST_EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "Loaded $LABEL"
echo "  producer:  $PRODUCER"
echo "  python:    $PYTHON"
echo "  atvscript: $ATVSCRIPT"
echo "  homepod:   $ATV_ID"
echo "  ingest:    $INGEST_URL"
echo "  logs:      /tmp/deskdashboard-nowplaying.log (.err)"
