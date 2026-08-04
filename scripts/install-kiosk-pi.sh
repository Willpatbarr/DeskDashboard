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
# Bound the restarts: if it fails 3x in 60s, give up instead of flashing the
# display forever. (systemd's default 5/10s is too loose to catch a ~5s loop.)
StartLimitIntervalSec=60
StartLimitBurst=3

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
ExecStart=$CAGE -d -- $BIN
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNITEOF

systemctl daemon-reload

cat <<DONE

Installed $SERVICE.service (NOT enabled or started yet — on purpose).
  user:   $RUN_USER (uid $RUN_UID)
  binary: $BIN
  cage:   $CAGE

cage needs the display to ITSELF, so you must switch to console boot BEFORE
enabling it. Do NOT 'systemctl start' it from the desktop or over SSH while the
desktop is running — cage will fight the desktop for the screen and flap.

Order (all recoverable — console mode keeps SSH + a text login):
  1. sudo raspi-config nonint do_boot_behaviour B2   # boot to console (frees the display)
  2. sudo systemctl enable $SERVICE                  # start it on the next boot
  3. sudo reboot                                      # comes up fullscreen

Check after reboot:  journalctl -u $SERVICE -b
                     systemctl status $SERVICE

Roll back to the normal desktop:
  sudo systemctl disable --now $SERVICE
  sudo raspi-config nonint do_boot_behaviour B4       # Desktop Autologin
  sudo reboot
DONE
