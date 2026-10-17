"""Validate data/hardware/hardware.json and print a launch-day profitability report.

    python tools/check_hardware.py

The report uses real network hashrate, subsidy, fees and price from btc_daily.csv.
It is information for balancing, not a gate. Exits non-zero if a check fails.
"""

from __future__ import annotations

import csv
import json
import sys
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HARDWARE = ROOT / "data" / "hardware" / "hardware.json"
EVENTS = ROOT / "data" / "events" / "historical.json"
DAILY = ROOT / "data" / "history" / "btc_daily.csv"

CAMPAIGN_START = date(2009, 1, 3)
CAMPAIGN_END = date(2024, 4, 20)
TH = 1e12
# Efficiency bands per tier in J/TH, from GDD 7.2 (corrected in M1), with room for real spec sheets.
EFFICIENCY_J_PER_TH = {
    "cpu_laptop": (1.5e7, 1.2e8),
    "cpu_desktop": (2e7, 1.5e8),
    "gpu_card": (4e5, 1e6),
    "fpga_board": (3e4, 1e5),
    "asic_gen1": (5e3, 1.2e4),
    "asic_gen2": (4e2, 7e2),
    "asic_gen2b": (2.2e2, 3e2),
    "asic_gen3": (90, 110),
    "asic_gen3b": (35, 45),
    "asic_gen4": (28, 35),
    "asic_gen5": (19, 23),
    "asic_gen5b": (16, 19),
}
POWER_PRICES_KWH = (0.05, 0.10, 0.15)
AVERAGE_DAYS = 7


def j_per_th(unit: dict) -> float:
    return unit["power_w"] / (unit["hashrate_hs"] / TH)


def load_daily() -> dict[date, dict]:
    with DAILY.open(newline="") as f:
        return {date.fromisoformat(r["date"]): r for r in csv.DictReader(f)}


def validate(units: list[dict], event_ids: set[str]) -> list[str]:
    errors = []
    ids = [u["id"] for u in units]
    if len(ids) != len(set(ids)):
        errors.append("duplicate ids")
    if set(ids) != set(EFFICIENCY_J_PER_TH):
        errors.append(f"unit ids differ from the expected tiers: {sorted(set(ids) ^ set(EFFICIENCY_J_PER_TH))}")

    for u in units:
        where = u["id"]
        d = date.fromisoformat(u["available_from"])
        if not CAMPAIGN_START <= d <= CAMPAIGN_END:
            errors.append(f"{where}: available_from {d} outside the campaign")
        if u["hashrate_hs"] <= 0 or u["power_w"] <= 0:
            errors.append(f"{where}: hashrate and power must be positive")
        elif where in EFFICIENCY_J_PER_TH:
            lo, hi = EFFICIENCY_J_PER_TH[where]
            eff = j_per_th(u)
            if not lo <= eff <= hi:
                errors.append(f"{where}: {eff:,.4g} J/TH outside the {lo:,.4g}-{hi:,.4g} band")
        if u.get("unlock_event") and u["unlock_event"] not in event_ids:
            errors.append(f"{where}: unlock_event {u['unlock_event']} not in historical.json")
        if not u["sources"]:
            errors.append(f"{where}: no sources")
        for s in u["sources"]:
            if not s.get("url", "").startswith("https://"):
                errors.append(f"{where}: source URL must be https: {s.get('url')}")
            for key in ("publisher", "title", "accessed"):
                if not s.get(key):
                    errors.append(f"{where}: source missing {key}")
        if "—" in json.dumps(u, ensure_ascii=False):
            errors.append(f"{where}: contains an em dash")

    # Each newer non-CPU tier must be more efficient than everything before it.
    ladder = sorted((u for u in units if not u["id"].startswith("cpu_")), key=lambda u: u["available_from"])
    for prev, cur in zip(ladder, ladder[1:]):
        if j_per_th(cur) >= j_per_th(prev):
            errors.append(f"{cur['id']} ({j_per_th(cur):,.4g} J/TH) is not more efficient than {prev['id']}")
    return errors


def usd(value: float) -> str:
    return f"-${-value:,.2f}" if value < 0 else f"${value:,.2f}"


def report(units: list[dict], daily: dict[date, dict]) -> list[str]:
    head = (
        "| Unit | Ships | J/TH | BTC/day | USD/day | Breakeven $/kWh | "
        + " | ".join(f"Margin at ${p:.2f}" for p in POWER_PRICES_KWH)
        + " | Payback at $0.10 |"
    )
    lines = [head, "|" + "---|" * (7 + len(POWER_PRICES_KWH))]
    for u in sorted(units, key=lambda u: (u["available_from"], u["id"])):
        d0 = date.fromisoformat(u["available_from"])
        window = [daily[d0 + timedelta(n)] for n in range(AVERAGE_DAYS) if d0 + timedelta(n) in daily]
        btc_day = sum(
            u["hashrate_hs"] / float(r["hashrate_hs_7d"]) * (float(r["subsidy_btc"]) + float(r["fees_btc"]))
            for r in window if float(r["hashrate_hs_7d"]) > 0
        ) / len(window)
        prices = [float(r["price_usd"]) for r in window if r["price_usd"]]
        kwh_day = u["power_w"] * 24 / 1000
        if prices:
            usd_day = btc_day * sum(prices) / len(prices)
            margins = [usd(usd_day - kwh_day * p) for p in POWER_PRICES_KWH]
            breakeven = f"${usd_day / kwh_day:,.3f}"
            net = usd_day - kwh_day * 0.10
            price = u.get("launch_price_usd")
            payback = f"{price / net:,.0f} days" if price and net > 0 else ("never" if price else "n/a")
            revenue = usd(usd_day)
        else:
            revenue, breakeven, margins, payback = "no market", "n/a", ["n/a"] * len(POWER_PRICES_KWH), "n/a"
        lines.append(
            f"| {u['id']} | {d0} | {j_per_th(u):,.4g} | {btc_day:,.4g} | {revenue} | {breakeven} | "
            + " | ".join(margins) + f" | {payback} |"
        )
    return lines


def main() -> int:
    units = json.loads(HARDWARE.read_text(encoding="utf-8"))["units"]
    event_ids = {e["id"] for e in json.loads(EVENTS.read_text(encoding="utf-8"))["events"]}
    errors = validate(units, event_ids)
    for msg in errors:
        print(f"FAIL {msg}")
    print(f"{len(units)} units: {len(errors)} problem(s)\n")
    print("Launch-day economics (7-day average from the ship date, real network data):\n")
    print("\n".join(report(units, load_daily())))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
