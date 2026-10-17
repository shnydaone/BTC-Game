"""Validate data/tuning/*.json and data/protocol/consensus.json.

    python tools/check_tuning.py

Every value is an object with value, unit and note. Tuning values also carry a basis
saying where the number comes from. Exits non-zero if any check fails.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TUNING = ROOT / "data" / "tuning"
PROTOCOL = ROOT / "data" / "protocol" / "consensus.json"

# gdd: stated in the GDD. locked: a decisions.md entry. source: a cited public figure.
# estimate: a judgment call, to be tuned with playtests and bot runs.
BASES = {"gdd", "locked", "source", "estimate"}


def strings(obj: object):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from strings(v)


def check_file(path: Path, needs_basis: bool) -> list[str]:
    where = path.relative_to(ROOT).as_posix()
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as err:
        return [f"{where}: invalid JSON ({err})"]
    errors = []
    for key in ("schema_version", "notes", "values"):
        if key not in doc:
            errors.append(f"{where}: missing {key}")
    for name, entry in doc.get("values", {}).items():
        if not isinstance(entry, dict) or "value" not in entry:
            errors.append(f"{where}: {name} must be an object with a value")
            continue
        for key in ("unit", "note"):
            if not entry.get(key):
                errors.append(f"{where}: {name} missing {key}")
        if needs_basis:
            basis = entry.get("basis")
            if basis not in BASES:
                errors.append(f"{where}: {name} basis must be one of {sorted(BASES)}, got {basis!r}")
            if basis == "source" and not str(entry.get("source", "")).startswith("https://"):
                errors.append(f"{where}: {name} has basis source but no https source URL")
    if not needs_basis and not doc.get("sources"):
        errors.append(f"{where}: protocol facts need sources")
    if any("—" in s for s in strings(doc)):
        errors.append(f"{where}: contains an em dash")
    return errors


def main() -> int:
    files = sorted(TUNING.glob("*.json"))
    errors = check_file(PROTOCOL, needs_basis=False)
    for path in files:
        errors += check_file(path, needs_basis=True)
    for msg in errors:
        print(f"FAIL {msg}")
    print(f"{len(files)} tuning file(s) and the protocol file: {len(errors)} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
