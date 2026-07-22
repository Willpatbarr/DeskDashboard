#!/usr/bin/env bash
# Install DeskDashboard as a boot-time kiosk on the Raspberry Pi: a systemd
# service that runs the SwiftCrossUI UI fullscreen under `cage` (a single-app
# Wayland kiosk compositor), restarting it on crash and bringing it up at boot.
#
# Run ON the Pi, as root:
#   sudo bash scripts/install-kiosk-pi.sh
#
# It: installs `cage` if missing, writes /etc/systemd/system/deskdashboard-ui.service
# pointed at your built binary, and enables it. It does NOT change your boot
# target or reboot — it prints those final manual steps (they're destructive:
# they replace the desktop with the kiosk).
set -euo pipefail

SERVICE="deskdashboard-ui"
UNIT="/etc/systemd/system/${SERVICE}.service"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ "$(uname -s)" = "Linux" ] || { echo "error: run this on the Pi (Linux)." >&2; exit 1; }
[ "$(id -u)" = "0" ] || { echo "error: run with sudo (needs apt + /etc/systemd)." >&2; exit 1; }

# The desktop user the kiosk runs as (the one who invoked sudo).
RUN_USER="${SUDO_USER:-root}"
[ "$RUN_USER" != "root" ] || { echo "error: run via 'sudo' as your normal user, not as root directly." >&2; exit 1; }
RUN_UID="$(id -u "$RUN_USER")"

# Prefer a release binary, fall back to the debug one.
if [ -x "$REPO_ROOT/.build/release/$SERVICE" ]; then
    BIN="$REPO_ROOT/.build/release/$SERVICE"
elif [ -x "$REPO_ROOT/.build/debug/$SERVICE" ]; then
    BIN="$REPO_ROOT/.build/debug/$SERVICE"
else
    echo "error: no built binary at .build/{release,debug}/$SERVICE." >&2
    echo "       Build it first: bash scripts/build-ui-pi.sh" >&2
    exit 1
fi

# --- cage --------------------------------------------------------------------
if ! command -v cage >/dev/null 2>&1; then
    echo "installing cage…"
    apt-get update
    apt-get install -y cage
fi
CAGE="$(command -v cage)"

# --- unit --------------------------------------------------------------------
echo "writing $UNIT"
cat > "$UNIT" <<UNITEOF
[Unit]
Description=DeskDashboard kiosk (cage + $SERVICE)
After=systemd-user-sessions.service getty@tty1.service
Conflicts=getty@tty1.service

[Service]
Type=simple
User=$RUN_USER
PAMName=login
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYReset=yes
TTYVHangup=yes
Environment=XDG_RUNTIME_DIR=/run/user/$RUN_UID
ExecStart=$CAGE -- $BIN
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNITEOF

systemctl daemon-reload
systemctl enable "$SERVICE.service"

cat <<DONE

Installed and enabled $SERVICE.service
  user:   $RUN_USER (uid $RUN_UID)
  binary: $BIN
  cage:   $CAGE

Two manual steps remain (they replace the desktop with the kiosk, so do them
when you're ready):

  1. Boot to console (frees tty1/the display from the desktop):
       sudo raspi-config nonint do_boot_behaviour B2   # Console Autologin
  2. Reboot:
       sudo reboot

After reboot the dashboard should come up fullscreen and restart itself if it
crashes. Logs: journalctl -u $SERVICE -b
Test without rebooting (stops the desktop!): sudo systemctl start $SERVICE

Roll back to the normal desktop:
  sudo systemctl disable --now $SERVICE
  sudo raspi-config nonint do_boot_behaviour B4        # Desktop Autologin
  sudo reboot
DONE
