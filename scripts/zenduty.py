#!/usr/bin/env python3
"""zenduty.py — confirm whether an incident was raised in Zenduty (the verify step of the alert loop).

Uses only the Python standard library so it runs anywhere (sandbox VM, CI) with no pip install.

Auth: set ZENDUTY_API_TOKEN (a Zenduty API/read token; this is NOT the webhook URL). The webhook URL
is what *sends* alerts into Zenduty; this token is what lets us *read back* the resulting incidents.

Examples:
  # any incident in the last 10 minutes whose title/summary contains "crashloop"
  ZENDUTY_API_TOKEN=... python3 scripts/zenduty.py incidents --since 10m --match crashloop

  # poll for up to 5 minutes until a matching incident appears (exit 0 = found, 1 = timed out)
  python3 scripts/zenduty.py wait --since 10m --match deployment-replica-mismatch \\
      --timeout 300 --interval 15

Notes:
  * The default endpoint/path follows Zenduty's documented REST API. If your account uses a
    different base or path, override with --base-url / --path. Verify against your Zenduty docs.
  * Matching is a case-insensitive substring over common text fields (title, summary, message).
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_BASE = "https://www.zenduty.com"
DEFAULT_PATH = "/api/incidents/"


def _epoch_from_since(since: str) -> float:
    """Parse '10m'/'2h'/'30s'/'90' (seconds) into an absolute epoch cutoff."""
    s = since.strip().lower()
    mult = {"s": 1, "m": 60, "h": 3600, "d": 86400}
    if s and s[-1] in mult:
        val = float(s[:-1]) * mult[s[-1]]
    else:
        val = float(s)
    return time.time() - val


def fetch_incidents(base_url: str, path: str, token: str, page_size: int = 50) -> list:
    url = base_url.rstrip("/") + path
    if "?" not in url:
        url += "?" + urllib.parse.urlencode({"page_size": page_size})
    req = urllib.request.Request(url, headers={
        "Authorization": f"Token {token}",
        "Accept": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"zenduty API HTTP {e.code}: {e.read().decode(errors='replace')[:300]}\n")
        raise
    # Zenduty may return a bare list or a paginated {results: [...]} object.
    if isinstance(data, dict):
        return data.get("results") or data.get("data") or []
    return data if isinstance(data, list) else []


def _text_of(inc: dict) -> str:
    parts = [str(inc.get(k, "")) for k in ("title", "summary", "message", "name")]
    return " ".join(parts).lower()


def _created_epoch(inc: dict) -> float:
    raw = inc.get("creation_date") or inc.get("created_at") or inc.get("created")
    if not raw:
        return 0.0
    for fmt in ("%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S"):
        try:
            return time.mktime(time.strptime(str(raw)[:26], fmt))
        except ValueError:
            continue
    return 0.0


def filter_incidents(incidents: list, since: str | None, match: str | None) -> list:
    cutoff = _epoch_from_since(since) if since else None
    needle = match.lower() if match else None
    out = []
    for inc in incidents:
        if needle and needle not in _text_of(inc):
            continue
        if cutoff is not None:
            ce = _created_epoch(inc)
            if ce and ce < cutoff:
                continue
        out.append(inc)
    return out


def cmd_incidents(args) -> int:
    inc = fetch_incidents(args.base_url, args.path, args.token)
    matched = filter_incidents(inc, args.since, args.match)
    print(json.dumps(matched, indent=2))
    sys.stderr.write(f"{len(matched)} matching incident(s) of {len(inc)} fetched\n")
    return 0 if matched else 1


def cmd_wait(args) -> int:
    deadline = None  # computed lazily to avoid importing time-of-day; use monotonic
    start = time.monotonic()
    while True:
        try:
            inc = fetch_incidents(args.base_url, args.path, args.token)
            matched = filter_incidents(inc, args.since, args.match)
        except Exception as e:  # transient API hiccup — keep polling
            sys.stderr.write(f"poll error: {e}\n")
            matched = []
        if matched:
            print(json.dumps(matched, indent=2))
            sys.stderr.write(f"matched after {int(time.monotonic()-start)}s\n")
            return 0
        if time.monotonic() - start >= args.timeout:
            sys.stderr.write(f"timed out after {args.timeout}s with no matching incident\n")
            return 1
        time.sleep(args.interval)


def main() -> int:
    p = argparse.ArgumentParser(description="Confirm a Zenduty incident was raised.")
    p.add_argument("--base-url", default=os.environ.get("ZENDUTY_BASE_URL", DEFAULT_BASE))
    p.add_argument("--path", default=os.environ.get("ZENDUTY_INCIDENTS_PATH", DEFAULT_PATH))
    p.add_argument("--token", default=os.environ.get("ZENDUTY_API_TOKEN", ""))
    sub = p.add_subparsers(dest="cmd", required=True)

    pi = sub.add_parser("incidents", help="list matching incidents (exit 1 if none)")
    pi.add_argument("--since", help="time window, e.g. 10m / 2h / 90 (seconds)")
    pi.add_argument("--match", help="case-insensitive substring to match in incident text")
    pi.set_defaults(func=cmd_incidents)

    pw = sub.add_parser("wait", help="poll until a matching incident appears")
    pw.add_argument("--since", help="time window, e.g. 10m")
    pw.add_argument("--match", help="case-insensitive substring to match")
    pw.add_argument("--timeout", type=float, default=300, help="max seconds to poll")
    pw.add_argument("--interval", type=float, default=15, help="seconds between polls")
    pw.set_defaults(func=cmd_wait)

    args = p.parse_args()
    if not args.token:
        sys.stderr.write("ZENDUTY_API_TOKEN not set (and --token not given). Cannot query Zenduty.\n")
        return 2
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
