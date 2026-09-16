# Updating the Cast Recruiter

Run every command from the repo root in a WSL terminal (`cd ~/projects/m3-toolkit`).
From Windows the folder is `\\wsl.localhost\Ubuntu\home\harvey\projects\m3-toolkit`.

## What changed → what to do

| You changed… | Run (steps below) | Deploy |
|---|---|---|
| Card text or stats in the sheet | nothing — the web app reads the sheet live | nothing |
| …and the text uses an icon not used before | 1, 3, 4, 3 | web app |
| Card names, IDs, classes, or added / removed / reordered rows | 1, 3, 5, 6 | web app, TTS deck (+ models if IDs or classes changed) |
| New card art (new Dextrous export) | 2, 3, 5, 6 | web app, TTS deck |
| An icon SVG or the footer logo | 4 | web app |
| Colours in `webapp/CastRecruiter.html` | 7 | web app |
| A TTS Lua script | — | re-paste it in TTS |

Plain text edits need nothing because the web app pulls card text straight from the `IN Cast` tab.
Steps 1 and 3 are still a cheap check after any sheet edit.

## Steps

1. **Export the CSV.** In the sheet, on the `IN Cast` tab: File → Download → CSV. Save it over
   `M3_TTS_DB - Cast.csv` in the repo root (rename it; the download says `IN Cast`).
2. **Add the Dextrous export.** Put `MonuMentuM DD-MM-YYYY.json` in `dextrous/`. The scripts use the
   newest date automatically. You can delete the older one.
3. **Validate.** `python3 dextrous/validate_cast.py` must end in `PASSED`. It names the card and the fix.
   The two icon messages:
   - *"isn't in the web app yet"* → run step 4.
   - *"there is no assets/inline icons/…"* → the token in the sheet has a typo, or the SVG is missing
     from `assets/inline icons/<type>/`.
4. **Embed icons.** `python3 dextrous/build_svg_sprite.py`. The web app can't load image files, so
   icons are copied into `CastRecruiter.html`. Only the icons the CSV uses are embedded, which is why
   a newly used icon needs this step.
5. **Compile.** `python3 dextrous/generate_card_images.py`. This writes `webapp/CardImages.gs` (where
   each card's art is) and stamps names, IDs and classes into the deck JSON. A Dextrous export has
   no names, so they're matched to the CSV **by row position**.
6. **Check the contact sheet.** `python3 dextrous/make_contact_sheet.py`, then open
   `dextrous/contact_sheet.html` and scroll: every name must match the art above it. This is the only
   check that catches the `DEX Cast` tab's row order drifting from `IN Cast`. Every other check
   still passes when that happens.
7. **Check contrast.** `python3 dextrous/check_theme_contrast.py` must pass.

Icon size: in `CastRecruiter.html`, `--stat-icon-size` sets the prowess, fortitude and ether icons (the dice are fixed at 1.15em).

## Deploy

- **Web app.** `cd webapp && clasp push`, or paste the changed files (`CastRecruiter.html`,
  `main.gs`, `CardImages.gs`) into the Apps Script editor. The `/dev` URL updates at once. To update
  the public URL:
  `clasp deploy -i AKfycbzJ_rRo1MT81RSvWaqHqFvRzJ9utCt0stRyWUT6TguOIscMNviKVxogu8qwfqyxaBbT`.
  **Never run a plain `clasp deploy`**: it creates a new public URL.
- **TTS deck.** Copy the stamped `dextrous/MonuMentuM DD-MM-YYYY.json` into TTS's Saved Objects
  folder, spawn it, and swap it for the old deck in the Cast zone.
- **TTS models** (only if card IDs or classes changed). On the injector token, click
  *Inject IDs to Models*, then save the models bag.
- **TTS scripts.** Re-paste the changed `.lua` onto its object. Never paste
  `Floating_Health_Tracker.lua` on its own. `Model_ID_Injector.lua` carries a copy of it, so change
  both files identically, re-paste the injector and re-run it.

## Save the work

```bash
git add -A && git commit -m "What changed" && git push
```
