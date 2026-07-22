# Producers

External feeders for the push-based widgets. A producer reads some real-world
source and POSTs it to a DeskDashboard ingest endpoint on a timer. The Swift app
stays pure-Foundation; anything Apple- or hardware-specific lives out here.

| Producer | Reads | POSTs to |
|----------|-------|----------|
| `now-playing-push.py` | HomePod now-playing via [pyatv](https://pyatv.dev) (`atvscript`) | `POST /ingest/now-playing` |

(Indoor temperature has its own producer elsewhere; Outdoor is pull-based and
needs no producer — the app fetches Open-Meteo itself.)

## Now-playing (HomePod → Music widget)

`nowplaying-cli` can't do this: it only reads the *local* Mac's MediaRemote, not
a HomePod. Reading the HomePod requires talking to it over the network with
pyatv (Companion/AirPlay), the true analog of the HomePod temperature path.

### Install pyatv

Homebrew's Python is externally managed (PEP 668), so plain `pip3 install` is
refused. Use **pipx**, and pin it to Python ≤ 3.13 — pyatv 0.18 crashes on
Python 3.14 (`RuntimeError: There is no current event loop`), which silently
shows up as "nothing playing".

```bash
brew install pipx
pipx ensurepath
pipx install --python /opt/homebrew/opt/python@3.12/libexec/bin/python3 pyatv
```

Find your HomePod's id (used as `DD_ATV_ID`) with `atvremote scan`.

### Install the LaunchAgent

`install-nowplaying-agent.sh` auto-detects this machine's paths (repo,
`atvscript`, `python3`), writes the plist, and loads it. Safe to re-run.

```bash
bash producers/install-nowplaying-agent.sh
```

Override per machine before running:

```bash
DD_ATV_ID=<homepod id> DD_INGEST_URL=http://<host>:8642/ingest/now-playing \
  bash producers/install-nowplaying-agent.sh
```

### Verify

```bash
tail -f /tmp/deskdashboard-nowplaying.log     # producer pushes (and .err)
```

You should see `[producer] -> {...} => {"stored":...}` every ~5s. If it always
says `stopped`/"nothing playing" with music actually playing, run
`~/.local/bin/atvscript --id <id> playing` directly — a traceback there means
the pyatv/Python version problem above.

## Bringing the whole system up from the mini

[`scripts/start-dashboard.sh`](../scripts/start-dashboard.sh) is a one-command
"bring it up" for the mini: it kickstarts the local producer LaunchAgents and
then `ssh`es to the Pi to restart the kiosk service (`deskdashboard-ui`) that
runs the UI. Run it in your mini login session:

```bash
bash scripts/start-dashboard.sh            # PI_HOST / SERVICE overridable via env
```

It checks key-based SSH first and prints the `ssh-keygen`/`ssh-copy-id` steps if
that isn't set up yet, and warns if a producer is still POSTing to `localhost`
instead of the Pi. Requires the Pi kiosk service (`scripts/install-kiosk-pi.sh`).

## Files

- `now-playing-push.py` — one-shot poller: `atvscript` → flat JSON → POST.
- `install-nowplaying-agent.sh` — generates the per-machine LaunchAgent (with
  paths detected for this host) into `~/Library/LaunchAgents/` and loads it.
