#!/usr/bin/env python3
"""Extract the brand palette and font list from `assets/branding/M3 Branding Guide.pdf`.

Why this exists: no PDF tooling is installed in this WSL environment (no poppler-utils,
no pypdf, no pip, and apt needs a sudo password), so neither `pdftotext` nor Claude's own
PDF page rendering works here. A PDF's content streams are just Flate-compressed text, and
the brand guide prints its hex codes as literal text -- so the palette can be read with
nothing but `zlib` and `re`.

Run from the repo root:

    python3 dextrous/extract_brand_palette.py

Writes nothing; prints what it finds. The curated result lives in
`assets/branding/palette-extracted.md`.
"""
import re
import sys
import zlib
from pathlib import Path

PDF = Path("assets/branding/M3 Branding Guide.pdf")

# Swatches are laid out 6 to a row on the palette page; the first row is the only
# one the guide labels by name.
PRIMARY_NAMES = ["RED WINE", "GOLD STONE", "BASIL LEAF", "DEEP WATER", "OFF-BLACK", "OFF-WHITE"]
ROW_LABELS = ["primary (named in the guide)", "accent row", "light row"]


def decompressed_streams(raw: bytes) -> list[bytes]:
    """Every FlateDecode stream we can inflate. Font programs inflate too; that's fine,
    they just won't contain readable text."""
    out = []
    for match in re.finditer(rb"stream\r?\n", raw):
        start = match.end()
        end = raw.find(b"endstream", start)
        if end < 0:
            continue
        try:
            out.append(zlib.decompress(raw[start:end]))
        except zlib.error:
            pass
    return out


def stream_text(stream: bytes) -> str:
    """Text drawn by a content stream, as one flat string.

    Only the literal-string operands are pulled out, so word spacing is approximate --
    the guide renders headings with per-glyph kerning, which is why labels come back as
    'DEEP W A TER'. Good enough to pair a swatch with its name; not a layout engine.
    """
    parts = [
        re.sub(rb"\\([()\\])", rb"\1", m.group(0)[1:-1]).decode("latin1")
        for m in re.finditer(rb"\((?:\\.|[^\\()])*\)", stream)
    ]
    return re.sub(r"\s+", " ", " ".join(p for p in parts if p.strip()))


def main() -> int:
    if not PDF.exists():
        print(f"ERROR: {PDF} not found. See assets/branding/README.md.", file=sys.stderr)
        return 1

    raw = PDF.read_bytes()
    streams = decompressed_streams(raw)

    # Pair each swatch with the RGB and CMYK printed beside it. Anchoring on the full
    # "RBG:/CMYK:/HEX:" triple (the guide's own typo for RGB included) is what keeps
    # binary font data out of the results -- a bare '#rrggbb' regex matches byte
    # sequences inside the embedded CFF programs and invents colours that don't exist.
    entries = []
    for stream in streams:
        text = stream_text(stream)
        for match in re.finditer(
            r"RBG:\s*([\d,\s]+?)\s*CMYK:\s*([\d,\s]+?)\s*HEX:\s*#?([0-9A-Fa-f ]{6,7})", text
        ):
            rgb, cmyk, hexcode = match.groups()
            entries.append(
                (
                    tuple(int(n) for n in rgb.split(",")),
                    tuple(int(n) for n in cmyk.split(",")),
                    "#" + hexcode.replace(" ", "").upper(),
                )
            )

    print(f"{PDF.name}: {len(streams)} inflatable streams, {len(entries)} swatches\n")

    mismatches = 0
    for i, (rgb, _cmyk, hexcode) in enumerate(entries):
        if i % 6 == 0:
            row = i // 6
            label = ROW_LABELS[row] if row < len(ROW_LABELS) else f"row {row + 1}"
            print(f"  --- {label} ---")
        derived = "#%02X%02X%02X" % rgb
        name = PRIMARY_NAMES[i] if i < len(PRIMARY_NAMES) else ""
        flag = "" if derived == hexcode else f"  <-- MISMATCH: rgb implies {derived}"
        print(f"  {hexcode}  rgb{rgb}  {name}{flag}")
        if derived != hexcode:
            mismatches += 1

    fonts = sorted(
        {
            # Subset-embedded fonts carry a 6-letter tag like "RVUFWP+"; strip it.
            re.sub(r"^[A-Z]{6}\+", "", m.group(1).decode("latin1"))
            for m in re.finditer(rb"/BaseFont\s*/([A-Za-z0-9+\-_,.]+)", raw)
        }
    )
    print("\n  --- embedded fonts ---")
    for font in fonts:
        print(f"  {font}")

    print(f"\nRGB/hex cross-check: {len(entries) - mismatches}/{len(entries)} agree")
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
