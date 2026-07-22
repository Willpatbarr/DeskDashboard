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

This installs `cage`, writes `/etc/systemd/system/deskdashboard-ui.service`
(running as your user, on `tty1`, `Restart=always`), and enables it. It does
**not** touch your boot target or reboot — those are the two manual steps it
prints, because they replace the desktop with the kiosk:

```bash
sudo raspi-config nonint do_boot_behaviour B2   # boot to console (frees tty1)
sudo reboot
```

## Verify

```bash
# Test now (this stops the desktop and takes over tty1):
sudo systemctl start deskdashboard-ui
journalctl -u deskdashboard-ui -b       # look for "ingest server on :8642"
```

After a reboot the dashboard should fill the screen and relaunch itself if it
exits. The ingest server still listens on `:8642`, so the producers need no
changes.

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
