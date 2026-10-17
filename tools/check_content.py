"""Validate the written content against the data it depends on.

    python tools/check_content.py

Checks data/names.json, data/codex/entries.json, data/events/cards.json and
data/mentor/act1.json: every reference resolves, every counterparty and machine has a
parody name, no em dashes, and text fits its length limit. Exits non-zero on failure.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

# Sim event types a Codex trigger or mentor message may name (see sim/*.gd result.add calls).
SIM_EVENTS = {
    "block_found", "difficulty_adjusted", "subsidy_halved", "hardware_arrived", "hardware_failed",
    "hardware_repaired", "machines_shut_off", "exchange_failed", "offer_made", "objective_met",
    "act_ended", "payment_missed", "payment_overdue", "restructured", "month_closed", "job_resumed",
    "loan_repaid", "pizza_milestone", "feature_unlocked", "codex_unlocked", "exchange_selected",
}
MODES = {"cypherpunk", "slashdot", "late"}
CARD_FIELDS = {"mentor", "meme", "business"}
MAX_CARD_LINE = 160
MAX_CODEX_TEXT = 420
MAX_MENTOR_TEXT = 320
MENTOR_LAST_DATE = "2011-06-30"  # GDD 11.2: the mentor stops in 2011


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def strings(obj: object):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from strings(v)


def main() -> int:
    errors: list[str] = []
    events = load(DATA / "events" / "historical.json")["events"]
    event_ids = {e["id"] for e in events}
    hardware_ids = {u["id"] for u in load(DATA / "hardware" / "hardware.json")["units"]}
    exchanges = load(DATA / "tuning" / "market.json")["values"]["exchanges"]["value"]
    names = load(DATA / "names.json")
    codex = load(DATA / "codex" / "entries.json")["entries"]
    cards = load(DATA / "events" / "cards.json")["cards"]
    mentor = load(DATA / "mentor" / "act1.json")["messages"]

    for path in ["names.json", "codex/entries.json", "events/cards.json", "mentor/act1.json"]:
        if any("—" in s for s in strings(load(DATA / path))):
            errors.append(f"{path}: contains an em dash")

    # Names: every machine and every counterparty the player can meet.
    counterparties = set(exchanges)
    for e in events:
        for fx in e["effects"]:
            if "counterparty" in fx:
                counterparties.add(fx["counterparty"])
    for unit in sorted(hardware_ids - set(names["units"])):
        errors.append(f"names.json: no name for unit {unit}")
    for cp in sorted(counterparties - set(names["counterparties"])):
        errors.append(f"names.json: no name for counterparty {cp}")
    if names.get("mentor_handle") not in names.get("mentor_handle_candidates", []):
        errors.append("names.json: mentor_handle is not one of the candidates")

    # Codex: every entry the events unlock exists; triggers name real sim events.
    referenced = {fx["entry"] for e in events for fx in e["effects"] if fx["type"] == "codex"}
    act12 = {fx["entry"] for e in events if e["act"] <= 2 for fx in e["effects"] if fx["type"] == "codex"}
    for entry in sorted(act12 - set(codex)):
        errors.append(f"codex: no entry for {entry} (unlocked by an Act 1-2 event)")
    for entry, c in codex.items():
        for key in ("title", "text"):
            if not c.get(key):
                errors.append(f"codex {entry}: missing {key}")
        if len(c.get("text", "")) > MAX_CODEX_TEXT:
            errors.append(f"codex {entry}: text over {MAX_CODEX_TEXT} characters")
        if "trigger" in c and c["trigger"] not in SIM_EVENTS:
            errors.append(f"codex {entry}: unknown trigger {c['trigger']}")
        if "trigger" not in c and entry not in referenced:
            errors.append(f"codex {entry}: nothing unlocks it")

    # Cards: keyed by real events, known fields, short lines, mentor only while present.
    dates = {e["id"]: e["date"] for e in events}
    for eid, card in cards.items():
        if eid not in event_ids:
            errors.append(f"cards: unknown event {eid}")
            continue
        for key, text in card.items():
            if key not in CARD_FIELDS:
                errors.append(f"cards {eid}: unknown field {key}")
            elif len(text) > MAX_CARD_LINE:
                errors.append(f"cards {eid}: {key} over {MAX_CARD_LINE} characters")
        if "mentor" in card and dates[eid] > MENTOR_LAST_DATE:
            errors.append(f"cards {eid}: mentor line after the mentor goes quiet")

    # Mentor: unique ids, one trigger each, valid modes and dates, mentor stops in 2011.
    ids = [m["id"] for m in mentor]
    if len(ids) != len(set(ids)):
        errors.append("mentor: duplicate ids")
    for m in mentor:
        where = f"mentor {m['id']}"
        if ("date" in m) == ("sim_event" in m):
            errors.append(f"{where}: needs exactly one of date or sim_event")
        if "sim_event" in m and m["sim_event"] not in SIM_EVENTS:
            errors.append(f"{where}: unknown sim_event {m['sim_event']}")
        if "date" in m and "expires" not in m:
            errors.append(f"{where}: a dated message needs expires")
        for key in ("date", "expires"):
            if key in m and m[key] > MENTOR_LAST_DATE:
                errors.append(f"{where}: {key} after the mentor goes quiet")
        if "sim_event" in m and m.get("expires", "9999") > MENTOR_LAST_DATE:
            errors.append(f"{where}: an event-triggered message needs expires by {MENTOR_LAST_DATE}")
        if not set(m.get("modes", [])) <= MODES:
            errors.append(f"{where}: unknown mode")
        if not m.get("subject") or not m.get("text"):
            errors.append(f"{where}: missing subject or text")
        if len(m.get("text", "")) > MAX_MENTOR_TEXT:
            errors.append(f"{where}: text over {MAX_MENTOR_TEXT} characters")

    for msg in errors:
        print(f"FAIL {msg}")
    print(f"{len(names['units'])} unit names, {len(names['counterparties'])} counterparties, {len(codex)} Codex entries, "
          f"{len(cards)} cards, {len(mentor)} mentor messages: {len(errors)} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
