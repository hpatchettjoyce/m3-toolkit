#!/usr/bin/env python3
"""Offline validator for the single-sheet cast database and its TTS deck export.

Nothing in this repo can be unit-tested locally -- Apps Script needs a deploy and TTS
needs the game running -- so this script is the one thing that runs offline. Every
later chunk of UPGRADE_PLAN.md leans on it before asking for a manual test.

Usage:
    python3 dextrous/validate_cast.py [--csv PATH] [--deck PATH]

Exits 0 when the data is sane, 1 with a readable report when it is not.

Section references below are to UPGRADE_PLAN.md.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CSV = REPO_ROOT / "M3_TTS_DB - Cast.csv"
DEFAULT_DECK = REPO_ROOT / "dextrous" / "MonuMentuM 14-09-2026.json"

# --- expectations -----------------------------------------------------------------

# The schema moved twice on 2026-09-14 (D7). A validator that silently reads the wrong
# columns is worse than one that refuses, so the header is checked exactly. See §2.2.
EXPECTED_HEADER = [
    "#", "Name", "Dominion", "Class", "Role", "Role Details", "ID",
    "Effect Name 1", "Effect Type 1", "Effect Details 1",
    "Effect Name 2", "Effect Type 2", "Effect Details 2",
    "Keywords", "Ether", "Prowess", "Fortitude", "Artwork", "#Artwork Config",
    "Flavour", "Lore", "Name Inspiration", "Art Direction", "Mechanic(s)",
]

# §2.1. Bump this when cards are genuinely added -- a mismatch means either a stale
# export or a roster change nobody recorded, and both deserve a loud failure.
EXPECTED_ROW_COUNT = 200

# §2.4. Dominion prefix -> the `Dominion` column value.
DOMINION_PREFIXES = {
    "01RHA": "Rhavlika",
    "02IRO": "Iro-Si-Khar",
    "03VOI": "Voisira",
    "04XAL": "Xalakith",
    "05AHE": "Ahèserec",
    "06VER": "Veritian",
}

# §2.3.
CLASSES = {"CHAMPION", "FAMILIAR", "MINION", "TALISMAN", "SPECIAL ACTION"}
ROLES = {"COMPANION", "SIGNATURE", ""}

# §2.4. The middle ID segment is for sorting only and is never parsed for meaning
# (D2) -- but it should still agree with the authoritative Role/Class columns, so a
# mis-sorted or mis-assigned ID gets caught here rather than downstream. Role wins
# where present: 4 of the 12 companions are MINION class and still carry `02COM`.
SEGMENT_BY_ROLE = {"COMPANION": "02COM", "SIGNATURE": "06SIG"}
SEGMENT_BY_CLASS = {
    "CHAMPION": "01CHP",
    "FAMILIAR": "03FAM",
    "MINION": "04MIN",
    "TALISMAN": "05TAL",
    "SPECIAL ACTION": "07SPA",
}

# §3.4. Closed vocabulary, verified across all 200 rows. An unexpected value means a
# data-entry slip, not a new category.
EFFECT_TYPES = {
    "ABILITY", "ACTION", "ATTACK ACTION", "FREE ACTION", "FREE ATTACK REACTION",
    "MANOEUVRE ACTION", "ATTACK EXERTION", "ATTACK MANOEUVRE ACTION",
    "FREE ATTACK ACTION", "SPECIAL ACTION",
}

ID_PATTERN = re.compile(r"^(\d{2}[A-Z]{3})-(\d{2}[A-Z]{3})-(\d{4})$")

# --- the normalising name match ---------------------------------------------------

# `Role Details` carries a Dextrous-safe transliteration of the champion's name:
# Dextrous cannot take commas and the `æ` ligature is avoided, so 5 of the 24 links
# do not match the champion's `Name` cell character-for-character. These are
# intentional (D1), not typos. Both sides must be normalised -- the champion's own
# `Name` still contains the comma and the ligature, so folding only one side fixes
# nothing.
#
# Chunk 2 ports this same logic into `main.gs`. Two implementations that disagree is
# the failure mode to avoid: if the validator passes but the web app drops a link,
# this function and its JavaScript twin are the first place to look.

LIGATURES = {
    "æ": "ae", "Æ": "ae",
    "œ": "oe", "Œ": "oe",
    "ß": "ss",
    "ø": "o", "Ø": "o",
    "đ": "d", "Đ": "d",
    "ł": "l", "Ł": "l",
}

_STRIPPED_PUNCTUATION = ",'’‘`.´"


def normalise_name(value: str) -> str:
    """Fold a champion name to its comparison form.

    1. NFKD-decompose and drop combining marks, then map the ligatures NFKD leaves
       alone (`æ`, `œ`, `ß`).
    2. Strip commas, apostrophes and periods.
    3. Collapse runs of whitespace, trim, casefold.
    """
    text = unicodedata.normalize("NFKD", value or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = "".join(LIGATURES.get(ch, ch) for ch in text)
    text = "".join("" if ch in _STRIPPED_PUNCTUATION else ch for ch in text)
    return " ".join(text.split()).casefold()


# --- reporting --------------------------------------------------------------------


class Report:
    """Collects failures so one run reports everything wrong, not just the first thing."""

    def __init__(self) -> None:
        self.failures: list[tuple[str, str]] = []
        self.notes: list[str] = []

    def fail(self, check: str, message: str) -> None:
        self.failures.append((check, message))

    def note(self, message: str) -> None:
        self.notes.append(message)

    @property
    def ok(self) -> bool:
        return not self.failures

    def render(self) -> str:
        lines: list[str] = []
        for note in self.notes:
            lines.append(f"  {note}")
        if self.failures:
            lines.append("")
            by_check: dict[str, list[str]] = defaultdict(list)
            for check, message in self.failures:
                by_check[check].append(message)
            lines.append(f"FAILED — {len(self.failures)} problem(s) in {len(by_check)} check(s):")
            for check, messages in by_check.items():
                lines.append("")
                lines.append(f"  {check}  ({len(messages)})")
                for message in messages[:25]:
                    lines.append(f"    - {message}")
                if len(messages) > 25:
                    lines.append(f"    … and {len(messages) - 25} more")
        else:
            lines.append("")
            lines.append("PASSED — all checks clean.")
        return "\n".join(lines)


def row_label(index: int, row: dict) -> str:
    """Spreadsheet row number (header is row 1), plus ID and name for eyeballing."""
    return f"row {index + 2} {row.get('ID', '?')} {row.get('Name', '?')!r}"


# --- CSV checks -------------------------------------------------------------------


def load_csv(path: Path, report: Report) -> list[dict] | None:
    if not path.exists():
        report.fail("csv file", f"not found: {path}")
        return None
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.reader(handle)
        try:
            header = next(reader)
        except StopIteration:
            report.fail("csv header", f"{path.name} is empty")
            return None
        header = [cell.strip() for cell in header]
        if header != EXPECTED_HEADER:
            missing = [c for c in EXPECTED_HEADER if c not in header]
            unexpected = [c for c in header if c not in EXPECTED_HEADER]
            detail = []
            if missing:
                detail.append(f"missing {missing}")
            if unexpected:
                detail.append(f"unexpected {unexpected}")
            if not detail:
                detail.append("same columns, different order")
            report.fail(
                "csv header",
                f"{path.name} header does not match the expected schema (§2.2): "
                + "; ".join(detail)
                + ". If you see 'Effect 1 - Name' or 'Flavour Text', this is a stale export (D7).",
            )
            return None
        rows = [dict(zip(header, cells)) for cells in reader if any(cell.strip() for cell in cells)]
    report.note(f"{path.name}: {len(rows)} rows, header matches §2.2")
    return rows


def check_rows(rows: list[dict], report: Report) -> None:
    if len(rows) != EXPECTED_ROW_COUNT:
        report.fail(
            "row count",
            f"expected {EXPECTED_ROW_COUNT} rows (§2.1), found {len(rows)}. "
            "If cards were genuinely added, update EXPECTED_ROW_COUNT.",
        )

    seen_ids: dict[str, int] = {}
    dominion_runs: list[str] = []

    for index, row in enumerate(rows):
        label = row_label(index, row)
        card_id = row["ID"].strip()
        dominion = row["Dominion"].strip()
        klass = row["Class"].strip()
        role = row["Role"].strip()
        role_details = row["Role Details"].strip()

        # --- ID ---
        match = ID_PATTERN.match(card_id)
        if not match:
            report.fail("id format", f"{label}: {card_id!r} is not DDxxx-DDxxx-DDDD")
            continue
        prefix, segment, sequence = match.groups()

        if card_id in seen_ids:
            report.fail(
                "id unique",
                f"{label}: duplicate of row {seen_ids[card_id] + 2}",
            )
        else:
            seen_ids[card_id] = index

        if sequence != f"{index + 1:04d}":
            report.fail(
                "id sequence",
                f"{label}: sequence {sequence} does not match its row position {index + 1:04d}",
            )

        if row["#"].strip() != f"{index + 1:04d}":
            report.fail(
                "row number column",
                f"{label}: '#' is {row['#'].strip()!r}, expected {index + 1:04d}",
            )

        # --- dominion ---
        expected_dominion = DOMINION_PREFIXES.get(prefix)
        if expected_dominion is None:
            report.fail("dominion prefix", f"{label}: unknown prefix {prefix!r}")
        elif expected_dominion != dominion:
            report.fail(
                "dominion prefix",
                f"{label}: prefix {prefix} means {expected_dominion!r}, column says {dominion!r}",
            )
        if not dominion_runs or dominion_runs[-1] != dominion:
            dominion_runs.append(dominion)

        # --- class and role ---
        if klass not in CLASSES:
            report.fail("class vocabulary", f"{label}: Class {klass!r} not in {sorted(CLASSES)}")
        if role not in ROLES:
            report.fail("role vocabulary", f"{label}: Role {role!r} not in {sorted(ROLES)}")

        expected_segment = SEGMENT_BY_ROLE.get(role) or SEGMENT_BY_CLASS.get(klass)
        if expected_segment and segment != expected_segment:
            report.fail(
                "id segment",
                f"{label}: {role or klass} should carry {expected_segment}, ID has {segment}",
            )

        # --- role details ---
        if role in ("COMPANION", "SIGNATURE"):
            if not role_details:
                report.fail("role details present", f"{label}: {role} with empty Role Details")
        elif role_details:
            report.fail(
                "role details empty",
                f"{label}: Role is {role or 'blank'} but Role Details says {role_details!r}",
            )

        # --- effects ---
        for slot in (1, 2):
            name = row[f"Effect Name {slot}"].strip()
            type_ = row[f"Effect Type {slot}"].strip()
            if bool(name) != bool(type_):
                populated, empty = ("Name", "Type") if name else ("Type", "Name")
                report.fail(
                    "effect name/type paired",
                    f"{label}: Effect {populated} {slot} is populated but Effect {empty} {slot} is empty",
                )
            if type_ and type_ not in EFFECT_TYPES:
                report.fail(
                    "effect type vocabulary",
                    f"{label}: Effect Type {slot} {type_!r} is not one of the 10 known types (§3.4)",
                )
            for column, value in ((f"Effect Name {slot}", name), (f"Effect Type {slot}", type_)):
                if "{" in value or "*" in value:
                    report.fail(
                        "effect markup",
                        f"{label}: {column} contains Dextrous markup {value!r} — stale export (D7)",
                    )

    # Dominion blocks must be contiguous: each dominion appears as exactly one run.
    repeated = [name for name, count in Counter(dominion_runs).items() if count > 1]
    if repeated:
        report.fail(
            "dominion blocks contiguous",
            f"these dominions appear in more than one block: {sorted(repeated)}",
        )

    census = Counter(row["Class"].strip() for row in rows)
    report.note("class census: " + ", ".join(f"{k} {v}" for k, v in sorted(census.items())))


def check_champion_links(rows: list[dict], report: Report) -> None:
    """Every COMPANION/SIGNATURE resolves to a champion in its own dominion (§3.1).

    The 5 transliterated forms (`æ`->`ae`, dropped commas) are intentional and must
    resolve cleanly — only a name that fails *after* normalisation is a failure.
    """
    champions: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for row in rows:
        if row["Class"].strip() == "CHAMPION":
            key = (row["Dominion"].strip(), normalise_name(row["Name"]))
            champions[key].append(row)

    for key, matches in champions.items():
        if len(matches) > 1:
            names = [m["Name"] for m in matches]
            report.fail(
                "champion name collision",
                f"{key[0]}: {len(matches)} champions normalise to {key[1]!r}: {names}",
            )

    linked = 0
    transliterated = 0
    for index, row in enumerate(rows):
        role = row["Role"].strip()
        if role not in ("COMPANION", "SIGNATURE"):
            continue
        role_details = row["Role Details"].strip()
        if not role_details:
            continue  # already reported by check_rows
        dominion = row["Dominion"].strip()
        key = (dominion, normalise_name(role_details))
        if key not in champions:
            available = sorted(
                r["Name"] for r in rows
                if r["Class"].strip() == "CHAMPION" and r["Dominion"].strip() == dominion
            )
            report.fail(
                "champion link",
                f"{row_label(index, row)}: Role Details {role_details!r} matches no champion "
                f"in {dominion} (champions there: {available})",
            )
            continue
        linked += 1
        if champions[key][0]["Name"].strip() != role_details:
            transliterated += 1

    report.note(
        f"champion links: {linked} resolved "
        f"({transliterated} via the §3.1 Dextrous-safe transliterations)"
    )


# --- deck checks ------------------------------------------------------------------


def check_deck(path: Path, csv_row_count: int, report: Report) -> None:
    if not path.exists():
        report.fail("deck file", f"not found: {path}")
        return
    try:
        deck_file = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.fail("deck file", f"{path.name} is not valid JSON: {exc}")
        return

    states = deck_file.get("ObjectStates") or []
    decks = [s for s in states if s.get("ContainedObjects")]
    if len(decks) != 1:
        report.fail(
            "deck object",
            f"{path.name}: expected exactly 1 deck in ObjectStates, found {len(decks)} "
            f"(§2.1 — the two old decks are now one 'Deck Cast')",
        )
        if not decks:
            return
    deck = decks[0]

    contained = deck.get("ContainedObjects") or []
    deck_ids = deck.get("DeckIDs") or []
    custom = deck.get("CustomDeck") or {}

    if len(contained) != csv_row_count:
        report.fail(
            "deck card count",
            f"{len(contained)} ContainedObjects vs {csv_row_count} CSV rows — "
            "injection is positional, so these must line up 1:1",
        )
    if len(deck_ids) != len(contained):
        report.fail(
            "deck ids length",
            f"{len(deck_ids)} DeckIDs vs {len(contained)} ContainedObjects",
        )

    for position, (card, deck_id) in enumerate(zip(contained, deck_ids)):
        card_id = card.get("CardID")
        if card_id is None:
            report.fail("deck card id", f"card {position + 1}: no CardID")
            continue
        if card_id != deck_id:
            report.fail(
                "deck ids order",
                f"card {position + 1}: CardID {card_id} but DeckIDs[{position}] is {deck_id}",
            )
        sheet = str(card_id // 100)
        if sheet not in custom:
            report.fail(
                "custom deck sheet",
                f"card {position + 1} (CardID {card_id}) references CustomDeck sheet "
                f"{sheet}, which does not exist (sheets: {sorted(custom)})",
            )
            continue
        slots = custom[sheet].get("NumWidth", 0) * custom[sheet].get("NumHeight", 0)
        if card_id % 100 >= slots:
            report.fail(
                "custom deck slot",
                f"card {position + 1} (CardID {card_id}) is slot {card_id % 100} on a "
                f"sheet with {slots} slots",
            )

    for sheet, spec in sorted(custom.items()):
        face = spec.get("FaceUrl") or spec.get("FaceURL")
        if not face:
            report.fail("custom deck face", f"sheet {sheet}: no FaceUrl")

    report.note(
        f"{path.name}: deck {deck.get('Nickname')!r}, {len(contained)} cards, "
        f"{len(custom)} CustomDeck sheet(s)"
    )


# --- main -------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV, help=f"default: {DEFAULT_CSV.name}")
    parser.add_argument("--deck", type=Path, default=DEFAULT_DECK, help=f"default: {DEFAULT_DECK.name}")
    args = parser.parse_args(argv)

    report = Report()
    print(f"Validating {args.csv.name} against {args.deck.name}")

    rows = load_csv(args.csv, report)
    if rows is not None:
        check_rows(rows, report)
        check_champion_links(rows, report)
        check_deck(args.deck, len(rows), report)

    print(report.render())
    return 0 if report.ok else 1


if __name__ == "__main__":
    sys.exit(main())
