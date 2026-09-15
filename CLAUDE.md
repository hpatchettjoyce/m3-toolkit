# Monumentum - Cast Recruiter

Web app for building and validating game rosters ("casts") for the tabletop game **Monumentum**, backed by card data from a Google Sheet. Built on Google Apps Script (GAS), deployed as a Google Web App. Lives in `webapp/`.

## Stack

- Backend: Google Apps Script (`.gs` files run in a single shared global namespace — no per-file scoping).
- Frontend: single-file vanilla SPA (`webapp/CastRecruiter.html`) — HTML + CSS custom properties + vanilla ES6 JS. No frameworks (React/Vue) or CSS libraries unless explicitly requested.
- Sync: [`clasp`](https://github.com/google/clasp) v3 for local development, since GAS doesn't run locally (`webapp/.clasp.json`, `webapp/appsscript.json`). **`.clasp.json` lists `.js` in `scriptExtensions`, so any `.js` file under `webapp/` is pushed into the flat GAS namespace** — keep test harnesses outside `webapp/`.

## Architecture

- `webapp/main.gs` — primary entry point: `doGet(e)` routes the Web App, `doPost(e)` receives webhooks (e.g. from Tabletop Simulator), and defines `getCardDatabase()` — the single source of card data for the frontend.
- `webapp/CastRecruiter.html` — the frontend SPA: layout, styling, state, validation, JSON export.
- `webapp/CardImages.gs` — **generated** card art map, keyed by card ID. Never hand-edit it; re-run `dextrous/generate_card_images.py`.

Data flow: the frontend loads via `doGet` → `HtmlService.createHtmlOutputFromFile('CastRecruiter')`, then asynchronously calls `google.script.run.withSuccessHandler(...).withFailureHandler(...).getCardDatabase()`.

Backend data source: the active spreadsheet's single cast tab — all 200 cards (Champion, Familiar, Minion, Talisman, Special Action). The old `IN Cha-Tal` / `IN SP` pair is gone. Classes are stored in all caps and normalised to Title Case at the parse boundary.

**`MATCH_SHEET_NAME` is not a second cast source — do not point it at a cast tab.** It is the *write* destination for the TTS webhook: `doPost` looks it up, creates it if absent, and `appendRow()`s a 9-column match record after every game (`main.gs:101-125`). It must stay `"IN TTS"` (see `PROJECT_NOTES.md:38`); aiming it at a card-data tab appends match logs onto the bottom of the cards.

There is also a `DEX Cast` tab in the spreadsheet. **Nothing in this repo reads it** — the web app uses `Cast`, and the compiler reads the exported CSV. It appears to be the Dextrous-facing copy used to render card faces, so a text fix made only in `Cast` will not reach the card art unless `DEX Cast` mirrors it.

**The tab name is `CAST_SHEET_NAME` at the top of `webapp/main.gs`.** It has been renamed before (`IN CAST` -> `Cast`), and `getSheetByName()` matches exactly — case and spacing included. If the tab is renamed, change that one constant, `clasp push`, and redeploy. `getCardDatabase()` lists every tab in the spreadsheet in its error when it can't find the configured one, so the correct name is in the error text itself.

Expected `getCardDatabase()` schema:
```json
{
  "dominions": ["Rhavlika", "Iro-Si-Khar", "Voisira", "..."],
  "champions": [{ "id": "01RHA-01CHP-0001", "uniqueId": "01RHA-01CHP-0001", "name": "Flint Dross", "dominion": "Rhavlika", "class": "Champion", "effect": "NAME | TYPE\ndetails...", "image": { "url": "...", "cols": 8, "rows": 6, "idx": 0 } }],
  "units": [{ "id": "01RHA-03FAM-0012", "name": "Caldrack", "class": "Familiar", "cost": 6, "isLoyal": true, "tiedChampionId": "01RHA-01CHP-0001" }],
  "specials": [{ "id": "01RHA-07SPA-0020", "name": "Thermal Venting", "cost": 0, "isSignature": false, "tiedChampionId": null }]
}
```

`id` is the card ID (`01RHA-01CHP-0001`), not a positional `champ_0`, and `tiedChampionId` uses the same key space so frontend link comparisons work. Art is looked up by card ID against `getCardImageMappings().cards`. `normaliseName()` in `main.gs` is the twin of `normalise_name()` in `dextrous/validate_cast.py` — **change both or neither**.

## Conventions & gotchas

- **One `getCardDatabase()` only**: since all `.gs` files share a flat global scope, two files defining the same function name silently override each other. This bit the project once (`CardDatabase.gs` used to define its own `getCardDatabase()`); that file has since been deleted, leaving `main.gs` as the sole definition. Don't reintroduce a second card-fetching implementation in another `.gs` file.
- Keep the `:root` CSS custom properties block intact (`--primary-colour`, `--accent-colour`, etc.) for consistent theming.
- UI `.container` max-width is `1200px` on desktop, stepping down through breakpoints at 1100px/900px/600px for mobile — keep panels self-contained at all sizes.

## Other repo contents

- `dextrous/` — card data JSON exports and `generate_card_images.py` for producing card art.
- `tts/` — Lua scripts for the Tabletop Simulator integration (loader, trackers, deploy scripts).
- `M3_TTS_DB - Cast.csv` at repo root — raw card data pulled from the `Cast` tab described above.

## Deployment

1. Open the bound Google Spreadsheet → **Extensions > Apps Script**.
2. Copy the contents of `webapp/*.gs` and `webapp/CastRecruiter.html` into the Apps Script editor (or `clasp push` from `webapp/`).
3. **Redeploy without changing the public URL** — `clasp deploy -i <deploymentId>` repoints the
   existing deployment at a new version. The live deployment is
   `AKfycbzJ_rRo1MT81RSvWaqHqFvRzJ9utCt0stRyWUT6TguOIscMNviKVxogu8qwfqyxaBbT`; `clasp list-deployments`
   confirms it. **A plain `clasp deploy` (or Deploy > New deployment) mints a new deployment with a
   new `/exec` URL** — only do that if a new URL is actually wanted. The separate `@HEAD` deployment
   serves the `/dev` URL, which always runs the latest `clasp push` and needs no deploy step.
