#!/usr/bin/env bash
# Bring the whole DeskDashboard system up from the Mac mini, in one command:
#   1. (re)start the local producer launchd agents (music now-playing, indoor temp)
#   2. ssh to the Pi and restart the kiosk systemd service that runs the UI
#
# Run this ON the mini, inside your normal login (Aqua) session — it uses
# `launchctl … gui/<uid>/…`, which isn't reachable from a plain remote shell.
#
# Prerequisites:
#   - key-based SSH from this mini to the Pi (the script checks and, if missing,
#     prints the one-time ssh-keygen / ssh-copy-id steps)
#   - the Pi kiosk service installed once: scripts/install-kiosk-pi.sh
#     (the ssh user needs sudo on the Pi; this uses `ssh -t` so sudo can prompt —
#      for unattended runs add a NOPASSWD sudoers rule for `systemctl … <service>`)
#
# Config via env:
#   PI_HOST   ssh target    (default willbarr@192.168.4.244)
#   SERVICE   systemd unit  (default deskdashboard-ui)
set -euo pipefail

PI_HOST="${PI_HOST:-willbarr@192.168.4.244}"
SERVICE="${SERVICE:-deskdashboard-ui}"
UID_NUM="$(id -u)"

# Producer launchd labels to kick. Any that aren't loaded are skipped (warned).
PRODUCERS=(
    com.willbarr.deskdashboard.nowplayingpush
    com.willbarr.deskdashboard.temppush
)

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }

# --- SSH preflight -----------------------------------------------------------
info "Checking key-based SSH to $PI_HOST …"
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$PI_HOST" true 2>/dev/null; then
    cat >&2 <<SETUP
error: can't SSH to $PI_HOST without a password prompt.

One-time setup (from this mini):
  [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
  ssh-copy-id $PI_HOST         # enter the Pi's password once

Then re-run. Point elsewhere with:  PI_HOST=user@host $0
SETUP
    exit 1
fi

# --- Local producers ---------------------------------------------------------
for label in "${PRODUCERS[@]}"; do
    if launchctl print "gui/$UID_NUM/$label" >/dev/null 2>&1; then
        info "kickstarting producer: $label"
        launchctl kickstart -k "gui/$UID_NUM/$label"
        # Sanity-check its ingest target: for a Pi-hosted UI it must point at the
        # Pi, not this machine.
        url="$(launchctl print "gui/$UID_NUM/$label" 2>/dev/null \
               | grep -oE 'DD_INGEST_URL => [^[:space:]]+' | awk '{print $3}' || true)"
        case "$url" in
            *127.0.0.1*|*localhost*)
                warn "$label posts to $url — for the Pi-hosted UI this should target ${PI_HOST#*@}:8642, not localhost." ;;
        esac
    else
        warn "producer not loaded on this machine, skipping: $label"
    fi
done

# --- Launch the UI on the Pi -------------------------------------------------
info "Restarting $SERVICE on $PI_HOST (sudo may prompt) …"
ssh -t "$PI_HOST" "sudo systemctl restart '$SERVICE'"

info "Pi service status:"
ssh "$PI_HOST" "systemctl is-active '$SERVICE'; systemctl --no-pager -n 5 status '$SERVICE' || true"

info "Up. The UI ingest server should be live on the Pi at :8642."
