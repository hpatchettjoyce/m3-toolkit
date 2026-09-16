#!/usr/bin/env python3
"""Render every injected card's art next to its injected name, as one HTML page.

Why this exists
---------------
A Dextrous export carries no names: `Nickname`, `GMNotes` and `Description` are
all blank, and the compiler fills them in *positionally*. The deck's card order
therefore has to match the CSV's row order exactly. When it doesn't -- because
the intermediate sheet that feeds Dextrous was re-ordered, say -- every card ends
up labelled with a different card's name, and nothing downstream can tell:

  * the deck is structurally perfect, so `validate_cast.py` passes,
  * the counts match, so the compiler's hard bails never fire,
  * every ID is unique and well-formed, so the web app loads happily.

The only thing that can catch it is a human looking at the art beside the name.
This page makes that a single scroll instead of 200 lookups in Tabletop
Simulator. Regenerate it after every Dextrous export, before trusting the deck.

Usage:
    python3 dextrous/make_contact_sheet.py [--deck PATH] [--out PATH] [--open]
"""

from __future__ import annotations

import argparse
import html
import json
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
# Newest Dextrous export by default, found the same way the compiler finds it
DECK_DIR = REPO / "dextrous"
DEFAULT_OUT = REPO / "dextrous" / "contact_sheet.html"

VERIFYCACHE = "{verifycache}"


class ContactSheetError(Exception):
    """Refuse loudly rather than emit a page that proves nothing."""


def face_url(sheet: dict) -> str:
    """This export spells the key `FaceUrl`; TTS's own docs say `FaceURL`."""
    url = sheet.get("FaceUrl") or sheet.get("FaceURL")
    if not url:
        raise ContactSheetError("a CustomDeck sheet has no FaceUrl/FaceURL")
    # TTS wants the prefix, a browser chokes on it.
    return url[len(VERIFYCACHE):] if url.startswith(VERIFYCACHE) else url


def load_cards(deck_path: Path) -> tuple[list[dict], dict]:
    if not deck_path.exists():
        raise ContactSheetError(f"deck not found: {deck_path}")
    deck = json.loads(deck_path.read_text(encoding="utf-8"))
    obj = deck["ObjectStates"][0]
    cards = obj["ContainedObjects"]
    sheets = obj["CustomDeck"]

    missing = sum(1 for c in cards if not c.get("GMNotes"))
    if missing:
        raise ContactSheetError(
            f"{missing} of {len(cards)} cards have no GMNotes -- this deck has not been "
            "injected. Run dextrous/generate_card_images.py first."
        )
    return cards, sheets


def build(cards: list[dict], sheets: dict) -> str:
    by_dominion: dict[str, list[dict]] = {}
    for card in cards:
        # IDs look like 02IRO-02COM-0036; the first segment is the dominion block.
        dominion = (card.get("GMNotes") or "")[:5] or "?????"
        by_dominion.setdefault(dominion, []).append(card)

    census = Counter(c.get("Description") or "?" for c in cards)
    summary = ", ".join(f"{k} {v}" for k, v in sorted(census.items()))

    parts: list[str] = []
    for dominion, group in by_dominion.items():
        parts.append(f'<h2>{html.escape(dominion)} <span class="count">{len(group)} cards</span></h2>')
        parts.append('<div class="grid">')
        for card in group:
            card_id = card["CardID"]
            sheet_key = str(card_id // 100)
            slot = card_id % 100
            sheet = sheets.get(sheet_key)
            if sheet is None:
                raise ContactSheetError(
                    f"card {card.get('GMNotes')} references CustomDeck sheet {sheet_key}, "
                    "which the deck does not define"
                )
            cols = int(sheet.get("NumWidth", 1))
            rows = int(sheet.get("NumHeight", 1))
            col, row = slot % cols, slot // cols
            # Same sprite maths as getCardStyle() in CastRecruiter.html.
            x = (col / (cols - 1) * 100) if cols > 1 else 0
            y = (row / (rows - 1) * 100) if rows > 1 else 0
            style = (
                f"background-image:url('{html.escape(face_url(sheet), quote=True)}');"
                f"background-size:{cols * 100}% {rows * 100}%;"
                f"background-position:{x:.4f}% {y:.4f}%;"
            )
            parts.append(
                '<figure>'
                f'<div class="art" style="{style}"></div>'
                f'<figcaption><b>{html.escape(card.get("Nickname") or "(no name)")}</b>'
                f'<span class="meta">{html.escape(card.get("Description") or "")}</span>'
                f'<span class="id">{html.escape(card.get("GMNotes") or "")}</span>'
                f'<span class="slot">sheet {sheet_key} / slot {slot}</span>'
                '</figcaption></figure>'
            )
        parts.append("</div>")

    return f"""<!doctype html>
<meta charset="utf-8">
<title>Cast contact sheet</title>
<style>
  :root {{ color-scheme: light dark; }}
  body {{ margin:0; padding:24px; font:14px/1.4 system-ui,-apple-system,Segoe UI,sans-serif;
         background:#14161a; color:#e8eaed; }}
  header {{ margin-bottom:24px; }}
  h1 {{ font-size:20px; margin:0 0 6px; }}
  .lede {{ color:#9aa0a6; max-width:70ch; }}
  h2 {{ font-size:15px; margin:28px 0 10px; border-bottom:1px solid #2a2e35; padding-bottom:6px; }}
  .count {{ color:#9aa0a6; font-weight:400; }}
  .grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(190px,1fr)); gap:14px; }}
  figure {{ margin:0; background:#1c1f24; border:1px solid #2a2e35; border-radius:8px; overflow:hidden; }}
  .art {{ width:100%; aspect-ratio:5/7; background-color:#000; background-repeat:no-repeat; }}
  figcaption {{ padding:8px 10px; display:flex; flex-direction:column; gap:2px; }}
  figcaption b {{ font-size:13px; }}
  .meta {{ color:#8ab4f8; font-size:11px; letter-spacing:.03em; }}
  .id {{ color:#9aa0a6; font-size:11px; font-family:ui-monospace,Menlo,Consolas,monospace; }}
  .slot {{ color:#5f6368; font-size:10px; }}
</style>
<header>
  <h1>Cast contact sheet &mdash; {len(cards)} cards</h1>
  <p class="lede">Each card shows the art the deck points at, with the name that was
  injected onto it. <b>If a name does not match the face above it, the deck's card order
  does not match the CSV's row order</b> and the injection is misaligned &mdash; nothing
  else downstream can detect that. Class census: {html.escape(summary)}.</p>
</header>
{"".join(parts)}
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--deck", type=Path, default=None, help="default: newest 'MonuMentuM *.json' in dextrous/")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()
    if args.deck is None:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from generate_card_images import CompileError, find_deck
        try:
            args.deck = find_deck(DECK_DIR)
        except CompileError as exc:
            print(f"  contact sheet: {exc}", file=sys.stderr)
            return 1

    try:
        cards, sheets = load_cards(args.deck)
        args.out.write_text(build(cards, sheets), encoding="utf-8")
    except ContactSheetError as err:
        print(f"  contact sheet: {err}", file=sys.stderr)
        return 1

    print(f"  wrote {args.out} -- {len(cards)} cards")
    print(f"  open it and check every name matches the face above it")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
