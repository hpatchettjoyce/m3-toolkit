#!/usr/bin/env python3
"""Compile the cast database and the TTS deck export into the web app's art map.

One CSV in, one deck JSON in; an ID-keyed `webapp/CardImages.gs` out and the deck
JSON injected in place with `Nickname`, `GMNotes` and `Description`.

Usage:
    python3 dextrous/generate_card_images.py [--csv PATH] [--deck PATH] [--out PATH]
                                             [--dry-run]

Exits 0 on success, 1 with a readable reason on any mismatch. The injection is
positional -- deck card N takes its identity from CSV row N -- so every check here
that can catch a shift is a hard failure rather than a warning. See UPGRADE_PLAN.md
§3.2 (why `Description` carries the class) and §3.3 (why the map is ID-keyed).
"""

from __future__ import annotations

import argparse
import csv
import datetime
import glob
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEXTROUS_DIR = REPO_ROOT / "dextrous"
DEFAULT_CSV = REPO_ROOT / "M3_TTS_DB - Cast.csv"
DEFAULT_OUT = REPO_ROOT / "webapp" / "CardImages.gs"

# The 2026-09-14 export is a single `Cast` deck with no qualifier in its name, so one
# glob replaces the old `Characters`/`Specials` pair. Those two superseded exports are
# still on disk and still match, so they are excluded by name -- picking one of them by
# mtime on a fresh clone would compile the wrong, differently-shaped file.
DECK_GLOB = "MonuMentuM *.json"
SUPERSEDED_DECK_QUALIFIERS = ("Characters", "Specials")

# Dextrous names its exports `MonuMentuM DD-MM-YYYY.json`. Ordering on that date beats
# ordering on mtime, which a clone or a checkout resets.
DECK_DATE_RE = re.compile(r"(\d{2})-(\d{2})-(\d{4})\.json$")

# The three columns this script reads. The pre-D7 schema spelled them `Name (str)` and
# `ID (str)`; reading those literally against the current header injected empty strings
# without erroring, which is the failure this check exists to prevent.
REQUIRED_COLUMNS = ("Name", "ID", "Class")


class CompileError(Exception):
    """A mismatch that must stop the compile rather than write shifted data."""


def clean_url(url: str | None) -> str:
    """Strip Dextrous's `{verifycache}` prefix; the browser and TTS both want the URL."""
    if not url:
        return ""
    prefix = "{verifycache}"
    if url.startswith(prefix):
        return url[len(prefix):]
    return url


def synthetic_id(name: str) -> str:
    """Deterministic fallback for a blank ID. The validator should mean it never fires."""
    return "SYN-" + "".join(c for c in name if c.isalnum()).upper()


def find_deck(directory: Path) -> Path:
    """Newest `MonuMentuM *.json` export, by the date in its filename."""
    candidates = [
        Path(p)
        for p in glob.glob(str(directory / DECK_GLOB))
        if not any(q in Path(p).name for q in SUPERSEDED_DECK_QUALIFIERS)
    ]
    if not candidates:
        raise CompileError(
            f"no deck export matching '{DECK_GLOB}' in {directory} "
            f"(excluding the superseded {'/'.join(SUPERSEDED_DECK_QUALIFIERS)} exports)"
        )

    def sort_key(path: Path) -> tuple[int, int, int, float]:
        match = DECK_DATE_RE.search(path.name)
        if match:
            day, month, year = (int(g) for g in match.groups())
            return (year, month, day, path.stat().st_mtime)
        # Undated name: fall back to mtime, and sort below anything dated.
        return (0, 0, 0, path.stat().st_mtime)

    return sorted(candidates, key=sort_key)[-1]


def load_rows(path: Path) -> list[dict]:
    """Read the cast CSV. `utf-8-sig` because the export carries a BOM."""
    if not path.exists():
        raise CompileError(f"CSV not found: {path}")
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise CompileError(f"CSV has no data rows: {path}")
    missing = [c for c in REQUIRED_COLUMNS if c not in rows[0]]
    if missing:
        raise CompileError(
            f"CSV is missing required column(s): {', '.join(missing)}. "
            f"Found: {', '.join(rows[0].keys())}"
        )
    return rows


def load_deck(path: Path) -> tuple[dict, dict]:
    """Return the parsed save file and its single deck object."""
    if not path.exists():
        raise CompileError(f"deck JSON not found: {path}")
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    states = data.get("ObjectStates") or []
    if len(states) != 1:
        raise CompileError(
            f"expected exactly 1 ObjectStates entry in {path.name}, found {len(states)}"
        )
    return data, states[0]


def compile_cards(rows: list[dict], deck: dict) -> list[dict]:
    """Pair each CSV row with its deck card, failing loudly on any shape mismatch.

    Returns one record per card, in deck order, carrying everything both outputs need.
    """
    contained = deck.get("ContainedObjects") or []
    deck_ids = deck.get("DeckIDs") or []
    custom_deck = deck.get("CustomDeck") or {}

    # The injection is positional. A count mismatch means the deck and the sheet have
    # drifted apart, and writing anyway would shift every card past the drift.
    if len(contained) != len(rows):
        raise CompileError(
            f"deck has {len(contained)} cards but the CSV has {len(rows)} rows -- "
            "the injection is positional, refusing to write a shifted deck"
        )
    if len(deck_ids) != len(contained):
        raise CompileError(
            f"deck has {len(deck_ids)} DeckIDs but {len(contained)} ContainedObjects"
        )

    cards = []
    seen: dict[str, int] = {}
    for index, (row, card_obj) in enumerate(zip(rows, contained)):
        spreadsheet_row = index + 2  # header is row 1
        name = (row.get("Name") or "").strip()
        card_id = (row.get("ID") or "").strip()
        card_class = (row.get("Class") or "").strip()

        if not name:
            raise CompileError(f"row {spreadsheet_row}: blank Name")
        if not card_id:
            card_id = synthetic_id(name)
        if not card_class:
            # §3.2: Chunk 5 reads this back off the card to set model health.
            raise CompileError(f"row {spreadsheet_row}: blank Class for '{name}'")

        # A duplicate would silently collapse two cards into one map entry.
        if card_id in seen:
            raise CompileError(
                f"row {spreadsheet_row}: duplicate ID '{card_id}', "
                f"already used by row {seen[card_id]}"
            )
        seen[card_id] = spreadsheet_row

        # DeckIDs[i] and ContainedObjects[i].CardID agree in the current export; prefer
        # the card's own CardID and check the pair, so a reordered DeckIDs list is caught.
        tts_card_id = card_obj.get("CardID")
        if tts_card_id is None:
            raise CompileError(f"row {spreadsheet_row}: deck card has no CardID")
        if tts_card_id != deck_ids[index]:
            raise CompileError(
                f"row {spreadsheet_row}: CardID {tts_card_id} does not match "
                f"DeckIDs[{index}] = {deck_ids[index]}"
            )

        sheet = str(tts_card_id // 100)
        slot = tts_card_id % 100
        spec = custom_deck.get(sheet)
        if spec is None:
            raise CompileError(
                f"row {spreadsheet_row}: CardID {tts_card_id} wants CustomDeck sheet "
                f"'{sheet}', which the deck does not have"
            )
        # The export writes FaceUrl/BackUrl; TTS's own saves use FaceURL/BackURL.
        face = spec.get("FaceUrl") or spec.get("FaceURL")
        if not face:
            raise CompileError(f"CustomDeck sheet '{sheet}': no FaceUrl")

        cards.append(
            {
                "obj": card_obj,
                "id": card_id,
                "name": name,
                "class": card_class,
                "url": clean_url(face),
                "cols": spec.get("NumWidth", 8),
                "rows": spec.get("NumHeight", 6),
                "idx": slot,
            }
        )
    return cards


def inject(cards: list[dict]) -> None:
    """Stamp identity onto each deck card, in place.

    `Nickname` is the hover name, `GMNotes` stays the plain ID so every existing
    consumer is untouched, and `Description` carries the class for §3.2.
    """
    for card in cards:
        obj = card["obj"]
        obj["Nickname"] = card["name"]
        obj["GMNotes"] = card["id"]
        obj["Description"] = card["class"]


def render_gs(cards: list[dict], generated_on: str) -> str:
    """Render the ID-keyed map. One card per line keeps a changed URL a one-line diff."""
    entries = []
    for card in cards:
        value = (
            f'"url": {json.dumps(card["url"])}, '
            f'"cols": {json.dumps(card["cols"])}, '
            f'"rows": {json.dumps(card["rows"])}, '
            f'"idx": {json.dumps(card["idx"])}'
        )
        entries.append(f"      {json.dumps(card['id'])}: {{{value}}}")
    body = ",\n".join(entries)
    return f"""/**
 * Auto-generated card image mappings from the Tabletop Simulator deck export.
 * Generated on: {generated_on}
 * DO NOT EDIT THIS FILE MANUALLY -- run dextrous/generate_card_images.py.
 *
 * Keyed by card ID, not by row index: the cast list is ordered in dominion blocks,
 * so any re-order would otherwise attach art to the wrong cards (UPGRADE_PLAN.md §3.3).
 */

function getCardImageMappings() {{
  return {{
    cards: {{
{body}
    }}
  }};
}}
"""


def write_deck(data: dict, path: Path) -> None:
    """Write the save file back in the shape Dextrous exports it.

    Minified, ASCII-escaped and without a trailing newline -- matching the export means
    an injection shows up as one changed line, and so does the next re-export, instead
    of the two formats fighting over the whole file on every round trip.
    """
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV,
                        help=f"default: {DEFAULT_CSV.name}")
    parser.add_argument("--deck", type=Path, default=None,
                        help=f"default: newest '{DECK_GLOB}' in {DEXTROUS_DIR.name}/")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help=f"default: {DEFAULT_OUT.relative_to(REPO_ROOT)}")
    parser.add_argument("--dry-run", action="store_true",
                        help="report what would be written, touch nothing")
    args = parser.parse_args(argv)

    try:
        deck_path = args.deck if args.deck is not None else find_deck(DEXTROUS_DIR)
        rows = load_rows(args.csv)
        data, deck = load_deck(deck_path)
        cards = compile_cards(rows, deck)
    except CompileError as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        return 1
    except (json.JSONDecodeError, OSError) as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        return 1

    print(f"  CSV:  {args.csv.name} -- {len(rows)} rows")
    print(f"  deck: {deck_path.name} -- {len(cards)} cards, "
          f"{len(deck.get('CustomDeck') or {})} CustomDeck sheet(s)")

    synthetic = [c["id"] for c in cards if c["id"].startswith("SYN-")]
    if synthetic:
        print(f"  note: {len(synthetic)} card(s) fell back to a synthetic ID: "
              f"{', '.join(synthetic[:5])}")

    inject(cards)
    generated_on = datetime.date.today().strftime("%A, %-d %B %Y")
    gs_content = render_gs(cards, generated_on)

    if args.dry_run:
        print(f"  dry run: would write {len(cards)} entries to {args.out}")
        print(f"  dry run: would inject {len(cards)} cards into {deck_path}")
        return 0

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(gs_content, encoding="utf-8")
    write_deck(data, deck_path)

    print(f"  wrote {args.out} -- {len(cards)} ID-keyed entries")
    print(f"  injected Nickname/GMNotes/Description into {deck_path.name}")
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
