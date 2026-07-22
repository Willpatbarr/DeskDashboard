# Kiosk + auto-start on the Pi

_Status as of 2026-07-22. Companion to [pi-ui-deploy.md](pi-ui-deploy.md)._

Makes `deskdashboard-ui` come up **fullscreen at boot** and **restart on crash**,
turning it from "an app you launch" into an appliance. It runs the UI under
[`cage`](https://github.com/cage-kiosk/cage) — a single-app Wayland kiosk
compositor — from a systemd service on `tty1`. (SwiftCrossUI has no in-app
fullscreen API, so fullscreen is the compositor's job.)

> **Not yet verified on hardware.** The seat/DRM/logind handoff is Pi-specific
> and wasn't run when this was written. Test with `sudo systemctl start
> deskdashboard-ui` before committing to boot-to-kiosk.

## Prerequisite

Build the UI first (see [pi-ui-deploy.md](pi-ui-deploy.md)); the installer points
the service at `.build/release/deskdashboard-ui` if present, else `.build/debug/`.
A release build is the better appliance target — rebuild with
`bash scripts/build-ui-pi.sh` once you've confirmed debug works (swap + capped
jobs make release safe now; see the OOM note there).

## Install

```bash
sudo bash scripts/install-kiosk-pi.sh
```

This installs `cage` and writes `/etc/systemd/system/deskdashboard-ui.service`
(runs as your user, on `tty1`, `Restart=always` but rate-limited to 3 starts /
60 s so a failure can't flash the display forever). It does **not** enable,
start, or reboot — on purpose.

> **Do NOT `systemctl start` this from the desktop or over SSH while the desktop
> is running.** `cage` is a compositor and needs the display to itself; started
> alongside the desktop it fights for `tty1` and flaps (start → lose display →
> restart → …). You must switch to console boot *first*.

## Enable it (the only safe order)

Every step here is recoverable — console mode keeps SSH and a text login even if
`cage` never comes up, so you can't get stuck.

```bash
sudo raspi-config nonint do_boot_behaviour B2   # 1. boot to console — frees the display
sudo systemctl enable deskdashboard-ui          # 2. start it on the next boot
sudo reboot                                      # 3. comes up fullscreen
```

## Verify (after the reboot)

```bash
systemctl status deskdashboard-ui --no-pager
journalctl -u deskdashboard-ui -b        # look for "ingest server on :8642"
```

The dashboard should fill the screen and relaunch itself if it exits. The ingest
server still listens on `:8642`, so the producers need no changes. If `cage`
fails, the rate-limit stops it after 3 tries (no flashing) and you're left at a
console with SSH working — check the journal, fix, `systemctl reset-failed
deskdashboard-ui`, retry.

## Roll back to the desktop

```bash
sudo systemctl disable --now deskdashboard-ui
sudo raspi-config nonint do_boot_behaviour B4   # Desktop Autologin
sudo reboot
```

## If it doesn't come up

- `journalctl -u deskdashboard-ui -b` — first place to look.
- **Black screen / no seat / DRM master errors:** confirm you booted to console
  (step above) so nothing else holds `tty1`/the display. `cage` needs the VT.
- **App exits immediately:** run the binary by hand from a desktop terminal to
  see its own error, then re-check the unit's `XDG_RUNTIME_DIR`/`User`.
- **Wrong binary path:** re-run the installer after building; it re-points
  `ExecStart` at whatever exists under `.build/`.
