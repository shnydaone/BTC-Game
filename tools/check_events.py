"""Validate data/events/historical.json against its rules and against btc_daily.csv.

    python tools/check_events.py                 # structure and data checks
    python tools/check_events.py --check-links   # also re-fetch every source URL

Exits non-zero if any check fails.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVENTS = ROOT / "data" / "events" / "historical.json"
DAILY = ROOT / "data" / "history" / "btc_daily.csv"

CAMPAIGN_START = date(2009, 1, 3)
CAMPAIGN_END = date(2024, 4, 20)
# An act ends on its halving day; that day belongs to the act it ends.
ACT_ENDS = [date(2012, 11, 28), date(2016, 7, 9), date(2020, 5, 11), date(2024, 4, 20)]
REPLAY_DAYS = (30, 180)

CATEGORIES = {"protocol", "market", "exchange", "lender", "bank", "regulation", "adoption", "industry", "mining"}
EFFECT_TYPES = {
    "game_start",          # campaign begins, first mentor message
    "price_available",     # BTC has a quoted price; selling still disabled
    "unlock",              # {feature}: enables a feature or hardware tier
    "pizza_offer",         # optional pizza deal and regret counter
    "network_disruption",  # brief mining disruption
    "codex",               # {entry}: unlocks a Codex entry
    "exchange_failure",    # {counterparty, haircut}: share of exchange holdings lost (1.0 = all)
    "forked_coins",        # {coin}: sell-or-hold choice for coins from a chain split
    "halving",             # {height, subsidy_btc}
    "act_end",             # {act}
    "market_shock",        # named price event; size comes from history, no extra effect
    "margin_pressure",     # margin calls and covenant tests on BTC-backed debt
    "credit_tightening",   # lenders pull back; financing terms worsen (size in tuning)
    "loan_recall",         # {counterparty}: BTC-backed loans from this lender are recalled
    "rival_bankruptcy",    # a named rival fails; assets go to auction
    "bank_freeze",         # {counterparty}: optional, cash deposits frozen for a few days
    "regional_ban",        # {region}: mining banned in a region, sites must relocate
    "investor_demand",     # {kind}: investor appetite shifts (treasury BTC, IPO window, ETF)
    "news",                # headline only
}
FIGURE_BASES = {"daily_close", "daily_change", "drawdown", "intraday", "onchain", "hashrate_7d", "external"}
FIGURE_TOLERANCE = 0.10


def load_daily() -> dict[date, dict]:
    with DAILY.open(newline="") as f:
        return {date.fromisoformat(r["date"]): r for r in csv.DictReader(f)}


def strings(obj: object):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from strings(v)


def act_for(d: date) -> int:
    return next(i + 1 for i, end in enumerate(ACT_ENDS) if d <= end)


def check_figure(fig: dict, daily: dict[date, dict]) -> str | None:
    """Return an error message, or None if the figure matches the data."""
    basis, value = fig["basis"], fig["value"]
    if basis in ("intraday", "external", "onchain"):
        return None  # not in the daily dataset; covered by the event's sources
    d0, d1 = date.fromisoformat(fig["from"]), date.fromisoformat(fig["to"])
    rows = [daily[d] for d in sorted(daily) if d0 <= d <= d1]
    prices = [float(r["price_usd"]) for r in rows if r["price_usd"]]
    if basis == "daily_close":
        stat = fig.get("stat", "max")
        actual = max(prices) if stat == "max" else min(prices)
    elif basis == "daily_change":
        actual = prices[-1] / prices[0] - 1
    elif basis == "drawdown":
        peak_rows = [float(daily[d]["price_usd"]) for d in sorted(daily)
                     if date.fromisoformat(fig["peak_from"]) <= d <= date.fromisoformat(fig["peak_to"])]
        actual = min(prices) / max(peak_rows) - 1
    elif basis == "hashrate_7d":
        before = [float(daily[d]["hashrate_hs_7d"]) for d in sorted(daily)
                  if date.fromisoformat(fig["peak_from"]) <= d <= date.fromisoformat(fig["peak_to"])]
        actual = min(float(r["hashrate_hs_7d"]) for r in rows) / max(before) - 1
    else:
        return f"unknown basis {basis}"
    if abs(actual - value) > abs(value) * FIGURE_TOLERANCE:
        return f"{fig['label']}: file says {value:,.4g}, data gives {actual:,.4g}"
    return None


def check_links(events: list[dict]) -> list[str]:
    """Re-fetch every source. 403s are listed for a manual browser check (some sites block scripts)."""
    errors, blocked = [], []
    for e in events:
        for s in e["sources"]:
            req = urllib.request.Request(s["url"], headers={"User-Agent": "Mozilla/5.0 (check_events.py)"})
            try:
                with urllib.request.urlopen(req, timeout=30):
                    pass
            except urllib.error.HTTPError as err:
                (blocked if err.code == 403 else errors).append(f"{e['id']}: {s['url']} returned {err.code}")
            except (urllib.error.URLError, TimeoutError) as err:
                errors.append(f"{e['id']}: {s['url']} failed ({err})")
    for msg in blocked:
        print(f"BLOCKED (check in a browser) {msg}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-links", action="store_true", help="re-fetch every source URL")
    args = parser.parse_args()

    doc = json.loads(EVENTS.read_text(encoding="utf-8"))
    events = doc["events"]
    daily = load_daily()
    errors: list[str] = []

    ids = [e["id"] for e in events]
    if len(ids) != len(set(ids)):
        errors.append("duplicate ids: " + ", ".join(sorted({i for i in ids if ids.count(i) > 1})))
    dates = [date.fromisoformat(e["date"]) for e in events]
    if dates != sorted(dates):
        errors.append("events are not in date order")

    for e, d in zip(events, dates):
        where = e["id"]
        if not CAMPAIGN_START <= d <= CAMPAIGN_END:
            errors.append(f"{where}: date {d} outside the campaign")
        if e["act"] != act_for(d):
            errors.append(f"{where}: act {e['act']} but {d} falls in act {act_for(d)}")
        if e["category"] not in CATEGORIES:
            errors.append(f"{where}: unknown category {e['category']}")
        for key in ("headline", "summary"):
            if not e.get(key):
                errors.append(f"{where}: missing {key}")
        if not e["sources"]:
            errors.append(f"{where}: no sources")
        for s in e["sources"]:
            if not s.get("url", "").startswith("https://"):
                errors.append(f"{where}: source URL must be https: {s.get('url')}")
            for key in ("publisher", "title", "accessed"):
                if not s.get(key):
                    errors.append(f"{where}: source missing {key}")
        for fx in e["effects"]:
            if fx["type"] not in EFFECT_TYPES:
                errors.append(f"{where}: unknown effect type {fx['type']}")
        if e.get("replay"):
            r0, r1 = date.fromisoformat(e["replay"]["start"]), date.fromisoformat(e["replay"]["end"])
            span = (r1 - r0).days
            if not REPLAY_DAYS[0] <= span <= REPLAY_DAYS[1]:
                errors.append(f"{where}: replay spans {span} days, needs {REPLAY_DAYS[0]}-{REPLAY_DAYS[1]}")
            # Fog of time: a replay shows only the past, so it ends on the event day at the latest.
            if not r0 < d or r1 > d:
                errors.append(f"{where}: replay window must start before and end by the event date")
            if r0 not in daily or r1 not in daily or not daily[r0]["price_usd"]:
                errors.append(f"{where}: replay window has no price data at its start")
        for fig in e.get("figures", []):
            if fig["basis"] not in FIGURE_BASES:
                errors.append(f"{where}: unknown figure basis {fig['basis']}")
            elif msg := check_figure(fig, daily):
                errors.append(f"{where}: {msg}")
        if any("—" in s for s in strings(e)):
            errors.append(f"{where}: contains an em dash")

    if args.check_links:
        errors += check_links(events)

    for msg in errors:
        print(f"FAIL {msg}")
    replays = sum(1 for e in events if e.get("replay"))
    sources = sum(len(e["sources"]) for e in events)
    print(f"{len(events)} events, {replays} replays, {sources} sources: {len(errors)} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
