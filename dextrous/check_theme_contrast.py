#!/usr/bin/env python3
"""Check the contrast of webapp/CastRecruiter.html's colour tokens.

The frontend's colours all live in one `:root` block, split into two families:
screen chrome (dark) and `--ink-*` (the printed sheet, which stays light on
white). This reads the tokens straight out of the file and asserts the
foreground/background pairs the app actually renders, so a token edit that makes
text unreadable fails here instead of in front of a player.

Pairs are listed with the rule that produces them, because the non-obvious ones
matter: `--success-colour` and `--warning-colour` are used BOTH as button fills
and as tracker text on a panel (CastRecruiter.html, updateTrackers()), so they
have to clear on both. Run with no arguments:

    python3 dextrous/check_theme_contrast.py

No dependencies. Exit status is 0 when every pair passes.
"""
import pathlib
import re
import sys

HTML = pathlib.Path(__file__).resolve().parent.parent / "webapp" / "CastRecruiter.html"

# WCAG 2.1 thresholds. Body text is AA at 4.5:1; a boundary that identifies a
# control, or a graphical cue carrying meaning, is 1.4.11 at 3:1. Surfaces that
# only need to read as separate layers get a nominal floor.
TEXT, UI, SURFACE = 4.5, 3.0, 1.2
# Two rules on the printed card are deliberately faint: the card exists to be
# printed at home, and a heavy hairline around an already-filled box is ink spent
# for nothing. They delimit nothing a reader has to find, so they are held to the
# surface floor rather than 1.4.11's 3:1. The floor is only just above 1.0, so it
# still catches the regression that matters - a decorative fill or rule set to
# the same white as the paper, which makes the stats row vanish entirely.
DECOR = 1.05

# (foreground token, background token, minimum, what renders it)
PAIRS = [
    # --- screen chrome, text ---
    ("--text-colour",         "--bg-colour",      TEXT, "body copy on the page ground"),
    ("--text-colour",         "--panel-bg",       TEXT, "body copy inside .container"),
    ("--text-colour",         "--field-bg",       TEXT, "typed text in select / textarea"),
    ("--text-colour",         "--surface-bg",     TEXT, "typed text in #import-input"),
    ("--heading-text-colour", "--panel-bg",       TEXT, "h3"),
    ("--subtle-text-colour",  "--panel-bg",       TEXT, ".loader, import modal copy"),
    ("--muted-text-colour",   "--panel-bg",       TEXT, ".status-label, .empty-message"),
    ("--primary-colour",      "--panel-bg",       TEXT, "h1, h2, #ether-tracker"),

    # --- screen chrome, text on filled buttons ---
    ("--on-fill-colour", "--primary-colour",        TEXT, ".print-overlay-header, #btn-import-top"),
    ("--on-fill-colour", "--primary-strong-colour", TEXT, "#btn-print"),
    ("--on-fill-colour", "--accent-colour",         TEXT, ".btn-export, .card-qty-input"),
    ("--on-fill-colour", "--accent-hover-colour",   TEXT, ".btn-export:hover"),
    ("--on-fill-colour", "--success-colour",        TEXT, ".btn-confirm-print, #btn-submit-import"),
    ("--on-fill-colour", "--success-hover-colour",  TEXT, ".btn-confirm-print:hover"),
    ("--on-fill-colour", "--neutral-colour",        TEXT, ".btn-close-print, #btn-cancel-import"),
    ("--on-fill-colour", "--neutral-hover-colour",  TEXT, ".btn-close-print:hover"),

    # --- semantic colours double as text; see updateTrackers() ---
    ("--success-colour", "--panel-bg",   TEXT, "ether/specials tracker, within budget"),
    ("--warning-colour", "--panel-bg",   TEXT, "ether/specials tracker, over budget"),
    ("--warning-colour", "--warning-bg", TEXT, ".warning-box copy"),

    # --- boundaries and cues ---
    ("--field-border-colour", "--field-bg",   UI, "select / textarea outline"),
    ("--field-border-colour", "--panel-bg",   UI, "select / textarea outline on a panel"),
    ("--warning-border",      "--warning-bg", UI, ".warning-box outline"),
    ("--accent-colour",       "--panel-bg",   UI, "selected card border and glow"),
    ("--panel-bg",            "--bg-colour",  SURFACE, ".container against the ground"),

    # --- ink: the printed sheet, which must stay legible on paper ---
    ("--ink-text-colour",  "--ink-paper",    TEXT, ".print-card body text"),
    ("--ink-title-colour", "--ink-paper",    TEXT, ".print-card-name"),
    ("--ink-subtle-colour","--ink-paper",    TEXT, ".print-card-subheader"),
    ("--ink-stat-text",    "--ink-stat-bg",  TEXT, ".print-card-stats"),
    ("--ink-stat-border",  "--ink-paper",    DECOR, ".print-card-stats outline (low-ink, decorative)"),
    ("--ink-stat-bg",      "--ink-paper",    DECOR, ".print-card-stats fill (low-ink, decorative)"),
    ("--ink-rule-colour",  "--ink-paper",    UI,   ".print-card-art-placeholder"),
    ("--ink-faction-fallback", "--ink-paper", UI,  ".print-card border, no dominion"),
]


def read_tokens(text):
    block = re.search(r":root \{(.*?)\n        \}", text, re.S)
    if not block:
        sys.exit("could not find the :root block in CastRecruiter.html")
    return dict(re.findall(r"(--[a-z0-9-]+)\s*:\s*(#[0-9A-Fa-f]{6})\s*;", block.group(1)))


def luminance(hex_colour):
    h = hex_colour.lstrip("#")
    channels = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    channels = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def ratio(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def main():
    text = HTML.read_text(encoding="utf-8")
    tokens = read_tokens(text)
    print(f"Checking {len(PAIRS)} colour pairs from {len(tokens)} tokens in {HTML.name}\n")

    failures = []
    for fg, bg, minimum, where in PAIRS:
        missing = [t for t in (fg, bg) if t not in tokens]
        if missing:
            failures.append(f"{', '.join(missing)} is not defined in :root  ({where})")
            print(f"  MISSING  {', '.join(missing):40} {where}")
            continue
        r = ratio(tokens[fg], tokens[bg])
        ok = r >= minimum
        if not ok:
            failures.append(f"{fg} on {bg} is {r:.2f}:1, needs {minimum}:1  ({where})")
        print(f"  {'ok  ' if ok else 'FAIL'}  {r:5.2f}:1 (min {minimum})  "
              f"{tokens[fg]} on {tokens[bg]}  {where}")

    # The print styles exist to save ink. A dark ink token means the theme leaked.
    print()
    for name, value in sorted(tokens.items()):
        if name.startswith("--ink-") and name.endswith("paper") and luminance(value) < 0.8:
            failures.append(f"{name} is {value}, which is not paper-white - the dark theme leaked into print")
            print(f"  FAIL  {name} = {value} is too dark to be paper")
    if not any(f.startswith("--ink-") for f in failures):
        print(f"  ok    --ink-paper is {tokens.get('--ink-paper')}; print stays light on white")

    print()
    if failures:
        print(f"FAILED — {len(failures)} problem(s):")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("PASSED — every pair clears its threshold.")
    return 0


sys.exit(main())
