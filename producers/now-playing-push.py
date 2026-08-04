#!/usr/bin/env python3
"""DeskDashboard now-playing producer.

Reads the HomePod's current track over the network with pyatv's `atvscript`
and POSTs a flat now-playing payload to the DeskDashboard ingest endpoint. This
is the true analog of the HomePod temperature producer: a network protocol
(Companion/AirPlay), not something running locally on the Mac. `nowplaying-cli`
can't do this because it only sees the local Mac's MediaRemote, not the HomePod.

One-shot by design: run it on a launchd timer (see the .plist alongside this
file). The widget advances elapsed time on its own between pushes, so a poll
every few seconds is plenty.

Config via environment variables (all optional):
  DD_ATV_ID     HomePod identifier for `atvremote --id`   (default below)
  DD_INGEST_URL full ingest URL   (default http://127.0.0.1:8642/ingest/now-playing)
  DD_ATVSCRIPT  path to atvscript (default: found on PATH / ~/Library/Python)
"""

import json
import os
import shutil
import subprocess
import sys
import urllib.request

ATV_ID = os.environ.get("DD_ATV_ID", "B2C043882063")  # "Bedroom" HomePod Mini
INGEST_URL = os.environ.get(
    "DD_INGEST_URL", "http://127.0.0.1:8642/ingest/now-playing"
)


def find_atvscript():
    if os.environ.get("DD_ATVSCRIPT"):
        return os.environ["DD_ATVSCRIPT"]
    found = shutil.which("atvscript")
    if found:
        return found
    # pip --user installs land here; glob across python versions.
    import glob

    for candidate in sorted(
        glob.glob(os.path.expanduser("~/Library/Python/*/bin/atvscript")),
        reverse=True,
    ):
        return candidate
    return "atvscript"


def read_now_playing():
    """Return the atvscript `playing` result as a dict, or None on failure."""
    cmd = [find_atvscript(), "--id", ATV_ID, "playing"]
    try:
        out = subprocess.run(
            cmd, capture_output=True, text=True, timeout=20
        ).stdout
    except (subprocess.TimeoutExpired, OSError) as error:
        print(f"[producer] atvscript failed: {error}", file=sys.stderr)
        return None

    # atvscript prints one JSON object per line; take the last valid one
    # (an SSL warning may precede it on stderr, but be defensive on stdout too).
    for line in reversed(out.strip().splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def to_payload(playing):
    """Map atvscript output to the flat ingest JSON, or a stopped marker."""
    if not playing or playing.get("result") != "success":
        return {"stopped": True}

    state = playing.get("device_state")  # playing | paused | idle | stopped | ...
    title = playing.get("title")
    if state in (None, "idle", "stopped", "loading") or not title:
        return {"stopped": True}

    payload = {"title": title, "isPlaying": state == "playing"}
    for key in ("artist", "album"):
        if playing.get(key):
            payload[key] = playing[key]
    if playing.get("position") is not None:
        payload["elapsed"] = playing["position"]
    if playing.get("total_time") is not None:
        payload["duration"] = playing["total_time"]
    return payload


def post(payload):
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        INGEST_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            body = response.read().decode("utf-8", "replace")
            print(f"[producer] -> {payload} => {body}")
    except OSError as error:
        print(f"[producer] POST failed: {error}", file=sys.stderr)
        return 1
    return 0


def main():
    payload = to_payload(read_now_playing())
    return post(payload)


if __name__ == "__main__":
    sys.exit(main())
