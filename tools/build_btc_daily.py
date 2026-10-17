"""Build data/history/btc_daily.csv: daily BTC price, hashrate, difficulty and fees.

Covers 2009-01-03 to 2024-12-31 by UTC date. Run from anywhere:

    python tools/build_btc_daily.py

Inputs (all raw files are cached in tools/raw/, which is not committed):
    tools/raw/bq_blocks_daily.csv       BigQuery export of tools/sql/btc_blocks_daily.sql (run by hand)
    tools/raw/mtgoxUSD.csv.gz           Mt. Gox trade prints, bitcoincharts archive via the Wayback Machine
    tools/raw/bitstamp_ohlc_daily.json  Bitstamp daily candles from its public API
    tools/data/price_anchors.csv        hand-entered pre-exchange prices, with sources

Outputs:
    data/history/btc_daily.csv          the dataset
    data/history/btc_daily_checks.md    validation results and GDD section 8 spot-checks
    data/history/SOURCES.md             sources, licenses and raw file hashes

The build stops with an error if any validation check fails.
"""

from __future__ import annotations

import csv
import gzip
import hashlib
import json
import math
import sys
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "tools" / "raw"
ANCHORS = ROOT / "tools" / "data" / "price_anchors.csv"
OUT_DIR = ROOT / "data" / "history"

START = date(2009, 1, 3)
END = date(2024, 12, 31)

BQ_FILE = RAW / "bq_blocks_daily.csv"
MTGOX_FILE = RAW / "mtgoxUSD.csv.gz"
MTGOX_URL = "https://web.archive.org/web/20161229014309id_/http://api.bitcoincharts.com/v1/csv/mtgoxUSD.csv.gz"
BITSTAMP_FILE = RAW / "bitstamp_ohlc_daily.json"
BITSTAMP_URL = "https://www.bitstamp.net/api/v2/ohlc/btcusd/"
BITSTAMP_FIRST = date(2011, 8, 18)

# Mt. Gox carried most volume until 2013; Bitstamp from then on avoids the Gox premium and outages.
SWITCH_TO_BITSTAMP = date(2013, 1, 1)

SATS = 100_000_000
DIFF1_TARGET = 0xFFFF * 2**208
HALVINGS = {
    210_000: date(2012, 11, 28),
    420_000: date(2016, 7, 9),
    630_000: date(2020, 5, 11),
    840_000: date(2024, 4, 20),
}
# Known difficulty values: first retarget above 1, and the value in force at the fourth halving.
DIFFICULTY_CHECKPOINTS = [
    (date(2009, 12, 30), 1.1828, 0.01),
    (date(2024, 4, 20), 86_388_558_925_171, 0.01),
]
HASHRATE_SMOOTH_DAYS = 7

COLUMNS = [
    "date", "price_usd", "price_source", "blocks", "height_end", "difficulty",
    "hashrate_hs", "hashrate_hs_7d", "fees_btc", "fees_per_block_btc", "subsidy_btc", "tx_count",
]


def days(start: date, end: date) -> list[date]:
    return [start + timedelta(n) for n in range((end - start).days + 1)]


def utc_date(ts: float) -> date:
    return datetime.fromtimestamp(ts, timezone.utc).date()


def bits_to_difficulty(bits: str) -> float:
    value = int(bits, 16)
    exponent, mantissa = value >> 24, value & 0xFFFFFF
    return DIFF1_TARGET / (mantissa * 256 ** (exponent - 3))


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------- downloads


def download_mtgox() -> None:
    if MTGOX_FILE.exists():
        return
    print(f"Downloading {MTGOX_URL}")
    tmp = MTGOX_FILE.with_suffix(".part")
    with requests.get(MTGOX_URL, stream=True, timeout=120) as r:
        r.raise_for_status()
        with tmp.open("wb") as f:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
    with gzip.open(tmp, "rt") as f:  # fail early on an HTML error page
        first = f.readline().split(",")
        if len(first) != 3:
            raise SystemExit(f"Unexpected Mt. Gox file format: {first!r}")
    tmp.replace(MTGOX_FILE)


def download_bitstamp() -> None:
    if BITSTAMP_FILE.exists():
        return
    print(f"Downloading Bitstamp daily candles from {BITSTAMP_URL}")
    candles: dict[str, dict] = {}
    cursor = datetime(BITSTAMP_FIRST.year, BITSTAMP_FIRST.month, BITSTAMP_FIRST.day, tzinfo=timezone.utc)
    end_ts = datetime(END.year, END.month, END.day, tzinfo=timezone.utc).timestamp()
    while cursor.timestamp() <= end_ts:
        params = {"step": 86400, "limit": 1000, "start": int(cursor.timestamp())}
        r = requests.get(BITSTAMP_URL, params=params, timeout=60)
        r.raise_for_status()
        batch = r.json()["data"]["ohlc"]
        if not batch:
            break
        for c in batch:
            candles[c["timestamp"]] = c
        cursor = datetime.fromtimestamp(int(batch[-1]["timestamp"]) + 86400, timezone.utc)
        time.sleep(1)
    BITSTAMP_FILE.write_text(json.dumps(sorted(candles.values(), key=lambda c: int(c["timestamp"]))))


# ---------------------------------------------------------------- loaders


def load_blocks() -> dict[date, dict]:
    if not BQ_FILE.exists():
        raise SystemExit(
            f"Missing {BQ_FILE.relative_to(ROOT)}.\n"
            "Run tools/sql/btc_blocks_daily.sql in the BigQuery console and save the result there as CSV."
        )
    out: dict[date, dict] = {}
    with BQ_FILE.open(newline="") as f:
        for row in csv.DictReader(f):
            out[date.fromisoformat(row["date"])] = {
                "blocks": int(row["blocks"]),
                "height_min": int(row["height_min"]),
                "height_max": int(row["height_max"]),
                "bits_last": row["bits_last"],
                "difficulty_sum": float(row["difficulty_sum"]),
                "tx_count": int(row["tx_count"]),
                "fees_sat": int(float(row["fees_sat"])),
                "subsidy_sat": int(float(row["subsidy_sat"])),
                "coinbase_out_sat": int(float(row["coinbase_out_sat"])),
            }
    return out


def load_mtgox() -> dict[date, tuple[float, float]]:
    """Daily (close, volume) from Mt. Gox trade prints: unixtime, price, amount."""
    last: dict[date, tuple[int, float]] = {}
    volume: dict[date, float] = {}
    with gzip.open(MTGOX_FILE, "rt") as f:
        for line in f:
            ts_s, price_s, amount_s = line.split(",")
            ts = int(ts_s)
            d = utc_date(ts)
            if d >= SWITCH_TO_BITSTAMP:
                continue
            price = float(price_s)
            if d not in last or ts >= last[d][0]:
                last[d] = (ts, price)
            volume[d] = volume.get(d, 0.0) + float(amount_s)
    return {d: (p, volume[d]) for d, (_, p) in last.items()}


def load_bitstamp() -> dict[date, tuple[float, float]]:
    candles = json.loads(BITSTAMP_FILE.read_text())
    return {utc_date(int(c["timestamp"])): (float(c["close"]), float(c["volume"])) for c in candles}


def load_anchors() -> dict[date, float]:
    with ANCHORS.open(newline="") as f:
        return {date.fromisoformat(r["date"]): float(r["price_usd"]) for r in csv.DictReader(f)}


# ---------------------------------------------------------------- build


def build_prices(all_days: list[date]) -> dict[date, tuple[float | None, str]]:
    anchors = load_anchors()
    mtgox = load_mtgox()
    bitstamp = load_bitstamp()

    prices: dict[date, tuple[float | None, str]] = {}
    for d in all_days:
        if d >= SWITCH_TO_BITSTAMP and d in bitstamp:
            prices[d] = (bitstamp[d][0], "bitstamp")
        elif d < SWITCH_TO_BITSTAMP and d in mtgox:
            prices[d] = (mtgox[d][0], "mtgox")
        elif d in anchors:
            prices[d] = (anchors[d], "anchor")

    # Before the first exchange trade: interpolate between anchors on a log scale.
    first_market = min(d for d, (_, s) in prices.items() if s in ("mtgox", "bitstamp"))
    known = sorted((d, p) for d, (p, _) in prices.items() if d <= first_market)
    for (d0, p0), (d1, p1) in zip(known, known[1:]):
        span = (d1 - d0).days
        for n in range(1, span):
            frac = n / span
            prices[d0 + timedelta(n)] = (math.exp(math.log(p0) + frac * (math.log(p1) - math.log(p0))), "anchor_interp")

    # Days with no trades after the market opened (exchange outages): carry the last close.
    first_price = min(prices)
    last_price: float | None = None
    for d in all_days:
        if d in prices:
            last_price = prices[d][0]
        elif d < first_price:
            prices[d] = (None, "none")
        else:
            prices[d] = (last_price, "ffill")
    return prices


def build_rows() -> tuple[list[dict], dict[date, dict]]:
    RAW.mkdir(parents=True, exist_ok=True)
    blocks = load_blocks()  # fail fast before downloading if the BigQuery export is missing
    download_mtgox()
    download_bitstamp()

    all_days = days(START, END)
    prices = build_prices(all_days)

    rows = []
    difficulty = 1.0
    height_end = 0
    for d in all_days:
        b = blocks.get(d)
        if b:
            difficulty = bits_to_difficulty(b["bits_last"])
            height_end = max(height_end, b["height_max"])
        n = b["blocks"] if b else 0
        fees_sat = b["fees_sat"] if b else 0
        price, source = prices[d]
        rows.append({
            "date": d,
            "price_usd": price,
            "price_source": source,
            "blocks": n,
            "height_end": height_end,
            "difficulty": difficulty,
            "hashrate_hs": (b["difficulty_sum"] * 2**32 / 86400) if b else 0.0,
            "fees_btc": fees_sat / SATS,
            "fees_per_block_btc": (fees_sat / n / SATS) if n else None,
            "subsidy_btc": (b["subsidy_sat"] / SATS) if b else 0.0,
            "tx_count": b["tx_count"] if b else 0,
        })

    half = HASHRATE_SMOOTH_DAYS // 2
    for i, row in enumerate(rows):
        window = rows[max(0, i - half): i + half + 1]
        row["hashrate_hs_7d"] = sum(r["hashrate_hs"] for r in window) / len(window)
    return rows, blocks


# ---------------------------------------------------------------- validation


def validate(rows: list[dict], blocks: dict[date, dict]) -> list[tuple[str, bool, str]]:
    checks: list[tuple[str, bool, str]] = []

    def check(name: str, ok: bool, detail: str) -> None:
        checks.append((name, ok, detail))

    dates = [r["date"] for r in rows]
    check("Every day present", dates == days(START, END), f"{len(dates)} rows, {dates[0]} to {dates[-1]}")

    unknown = sorted(d for d in blocks if not START <= d <= END)
    check("No block days outside the range", not unknown, f"{len(unknown)} outside" if unknown else "ok")

    total = sum(b["blocks"] for b in blocks.values())
    top = max(b["height_max"] for b in blocks.values())
    check("Block count matches heights (no gaps or duplicates)", total == top + 1, f"{total:,} blocks, top height {top:,}")

    ends = [r["height_end"] for r in rows]
    check("height_end never decreases", all(a <= b for a, b in zip(ends, ends[1:])), "ok")

    for height, expected in HALVINGS.items():
        actual = next((d for d, b in sorted(blocks.items()) if b["height_min"] <= height <= b["height_max"]), None)
        check(f"Halving at height {height:,} on {expected}", actual == expected, f"found {actual}")

    by_date = {r["date"]: r for r in rows}
    early = [r for r in rows if r["date"] < date(2009, 12, 30)]
    check("Difficulty is 1 before 2009-12-30", all(abs(r["difficulty"] - 1.0) < 1e-9 for r in early), "ok")
    for d, expected, tol in DIFFICULTY_CHECKPOINTS:
        got = by_date[d]["difficulty"]
        check(f"Difficulty on {d} near {expected:,.4g}", abs(got / expected - 1) <= tol, f"got {got:,.6g}")

    over = [d for d, b in blocks.items() if b["coinbase_out_sat"] > b["subsidy_sat"] + b["fees_sat"]]
    check("Coinbase never claims more than subsidy plus fees", not over, f"{len(over)} days over: {over[:5]}" if over else "ok")

    unclaimed = sum(b["subsidy_sat"] + b["fees_sat"] - b["coinbase_out_sat"] for b in blocks.values()) / SATS
    check("Unclaimed rewards are small", unclaimed < 100, f"{unclaimed:,.4f} BTC never claimed by miners")

    priced = [r for r in rows if r["price_usd"] is not None]
    check("Prices are positive", all(r["price_usd"] > 0 for r in priced), f"{len(priced)} priced days")
    check("No price before 2009-10-05", priced[0]["date"] == date(2009, 10, 5), f"first price {priced[0]['date']}")
    ffill = [r["date"] for r in rows if r["price_source"] == "ffill"]
    check("Forward-filled price days are few", len(ffill) <= 30, f"{len(ffill)} days: {ffill[:10]}")
    return checks


def spot_checks(rows: list[dict]) -> list[tuple[str, str, str]]:
    """GDD section 8 figures against the built data. Daily closes sit below intraday highs."""
    by_date = {r["date"]: r for r in rows}

    def closes(a: str, b: str) -> list[tuple[date, float]]:
        d0, d1 = date.fromisoformat(a), date.fromisoformat(b)
        return [(r["date"], r["price_usd"]) for r in rows if d0 <= r["date"] <= d1 and r["price_usd"]]

    def peak(a: str, b: str) -> str:
        d, p = max(closes(a, b), key=lambda x: x[1])
        return f"${p:,.2f} on {d}"

    def low(a: str, b: str) -> str:
        d, p = min(closes(a, b), key=lambda x: x[1])
        return f"${p:,.2f} on {d}"

    def change(a: str, b: str) -> str:
        p0, p1 = by_date[date.fromisoformat(a)]["price_usd"], by_date[date.fromisoformat(b)]["price_usd"]
        return f"{p1 / p0 - 1:+.1%} ({a} close to {b} close)"

    def drawdown(peak_range: tuple[str, str], low_range: tuple[str, str]) -> str:
        hi = max(p for _, p in closes(*peak_range))
        lo = min(p for _, p in closes(*low_range))
        return f"{lo / hi - 1:+.1%} (${hi:,.0f} to ${lo:,.0f})"

    def hash_drop() -> str:
        may = [r["hashrate_hs_7d"] for r in rows if date(2021, 5, 1) <= r["date"] <= date(2021, 5, 31)]
        summer = [r["hashrate_hs_7d"] for r in rows if date(2021, 6, 1) <= r["date"] <= date(2021, 7, 31)]
        return f"{min(summer) / max(may) - 1:+.1%} (7-day: {max(may) / 1e18:.0f} to {min(summer) / 1e18:.0f} EH/s)"

    return [
        ("2009-10 first price", "a fraction of a cent", f"${by_date[date(2009, 10, 5)]['price_usd']:.6f}"),
        ("2011-06 first bubble peak", "~$30", peak("2011-06-01", "2011-06-30")),
        ("2011 post-crash low", "~$2 by November", low("2011-09-01", "2011-12-31")),
        ("2013-04 spike", "~$260", peak("2013-04-01", "2013-04-30")),
        ("2013-11/12 rally", "past $1,000", peak("2013-11-01", "2013-12-31")),
        ("2015-01 bottom", "~$170", low("2015-01-01", "2015-01-31")),
        ("2017-12 peak", "near $20,000", peak("2017-12-01", "2017-12-31")),
        ("2018 bear drawdown", "~-84% to ~$3,200", drawdown(("2017-12-01", "2017-12-31"), ("2018-01-01", "2018-12-31"))),
        ("2020-03-12 Black Thursday", "~-50% in a day", change("2020-03-11", "2020-03-12")),
        ("2021-04 peak", "~$64,000", peak("2021-04-01", "2021-04-30")),
        ("2021 China ban hashrate", "roughly halves", hash_drop()),
        ("2021-11 peak", "~$69,000", peak("2021-11-01", "2021-11-30")),
        ("2022-11 FTX low", "~$15,500", low("2022-11-01", "2022-12-31")),
        ("2024-03 peak", "~$73,000", peak("2024-03-01", "2024-03-31")),
    ]


# ---------------------------------------------------------------- output


def fmt(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        return f"{value:.10g}"
    return str(value)


def write_outputs(rows: list[dict], checks: list[tuple[str, bool, str]], spots: list[tuple[str, str, str]]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with (OUT_DIR / "btc_daily.csv").open("w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(COLUMNS)
        for r in rows:
            w.writerow(fmt(r[c]) for c in COLUMNS)

    lines = [
        "# btc_daily.csv checks",
        "",
        f"Generated by `tools/build_btc_daily.py` on {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC.",
        "",
        "## Validation",
        "",
        "| Check | Result | Detail |",
        "|---|---|---|",
        *[f"| {n} | {'pass' if ok else 'FAIL'} | {d} |" for n, ok, d in checks],
        "",
        "## GDD section 8 spot-checks",
        "",
        "Prices are UTC daily closes, so peaks read lower and lows higher than intraday figures.",
        "",
        "| Event | GDD says | Data shows |",
        "|---|---|---|",
        *[f"| {n} | {g} | {v} |" for n, g, v in spots],
        "",
        "## Price sources by day",
        "",
        "| Source | Days |",
        "|---|---|",
    ]
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["price_source"]] = counts.get(r["price_source"], 0) + 1
    lines += [f"| {s} | {n:,} |" for s, n in counts.items()]
    (OUT_DIR / "btc_daily_checks.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    sources = f"""# Sources for btc_daily.csv

Built by `tools/build_btc_daily.py`. Dates are UTC. Prices are daily closes in USD.

## Columns

| Column | Meaning |
|---|---|
| date | UTC date |
| price_usd | Daily close in USD. Blank before the first published rate (2009-10-05). |
| price_source | `none`, `anchor` (hand-entered, see `tools/data/price_anchors.csv`), `anchor_interp` (log interpolation between anchors), `mtgox`, `bitstamp`, `ffill` (no trades that day, last close carried) |
| blocks | Blocks with a timestamp on that date |
| height_end | Highest block height seen so far |
| difficulty | Difficulty of the highest block that day (carried on days with no blocks) |
| hashrate_hs | Estimated network hashrate in H/s: sum of block difficulty x 2^32 / 86,400. Hashrate cannot be measured directly; every source estimates it this way. |
| hashrate_hs_7d | Centered {HASHRATE_SMOOTH_DAYS}-day mean of hashrate_hs. Use this for charts; the daily value is noisy. |
| fees_btc | Total transaction fees paid that day |
| fees_per_block_btc | fees_btc / blocks (blank on days with no blocks) |
| subsidy_btc | Total block subsidy that day |
| tx_count | Transactions, including coinbase |

## Sources

| Data | Source | Terms |
|---|---|---|
| Blocks, difficulty, fees, subsidy | Google BigQuery public dataset `bigquery-public-data.crypto_bitcoin`, query in `tools/sql/btc_blocks_daily.sql` | Public blockchain data. No third-party license on the underlying facts. |
| Price 2010-07-18 to {SWITCH_TO_BITSTAMP - timedelta(1)} | Mt. Gox trade prints, bitcoincharts.com archive (Internet Archive snapshot: {MTGOX_URL}) | **Unknown.** bitcoincharts.com is offline and published no license. Open item for Eric. |
| Price {SWITCH_TO_BITSTAMP} to {END} | Bitstamp public API, `/api/v2/ohlc/btcusd/` daily candles | Bitstamp allows commercial redistribution of its exchange data and asks commercial users to sign a Data License Agreement (partners@bitstamp.net). |
| Price 2009-10-05 to 2010-07-17 | Hand-entered anchors with sources in `tools/data/price_anchors.csv` | Historical facts, cited per row. |

## Raw files

| File | SHA-256 |
|---|---|
""" + "\n".join(
        f"| `tools/raw/{p.name}` | `{sha256(p)}` |" for p in (BQ_FILE, MTGOX_FILE, BITSTAMP_FILE)
    ) + "\n"
    (OUT_DIR / "SOURCES.md").write_text(sources, encoding="utf-8")


def main() -> int:
    rows, blocks = build_rows()
    checks = validate(rows, blocks)
    spots = spot_checks(rows)
    write_outputs(rows, checks, spots)

    for name, ok, detail in checks:
        print(f"[{'pass' if ok else 'FAIL'}] {name}: {detail}")
    print()
    for name, gdd, value in spots:
        print(f"{name}: GDD {gdd} | data {value}")

    failed = [n for n, ok, _ in checks if not ok]
    if failed:
        print(f"\n{len(failed)} check(s) failed. See data/history/btc_daily_checks.md.", file=sys.stderr)
        return 1
    print(f"\nWrote {len(rows)} rows to data/history/btc_daily.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
