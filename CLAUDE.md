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

Backend data source: the bound spreadsheet's single `IN Cast` tab — all 200 cards (Champion, Familiar, Minion, Talisman, Special Action). The old `IN Cha-Tal` / `IN SP` pair is gone. Classes are stored in all caps and normalised to Title Case at the parse boundary.

**`MATCH_SHEET_NAME` is not a second cast source — do not point it at a cast tab.** It is the *write* destination for the TTS webhook: `doPost` looks it up, creates it if absent, and `appendRow()`s a 9-column match record after every game (`main.gs:101-125`). It must stay `"IN TTS"` (see `PROJECT_NOTES.md:40`); aiming it at a card-data tab appends match logs onto the bottom of the cards.

**`IN Cast`'s row order is canonical, and `validate_cast.py` enforces it** — each row's `#` column and its ID's trailing sequence must equal its row position, so the rows cannot be reordered to fix anything. The card order Dextrous renders comes from `DEX Cast`, and **`DEX Cast` must mirror `IN Cast` row for row.** When the two drift, the compiler's positional injection silently labels every affected card with a different card's name; see `dextrous/make_contact_sheet.py` for the only check that catches it.

There is also a `DEX Cast` tab in the spreadsheet. **Nothing in this repo reads it** — the web app uses `Cast`, and the compiler reads the exported CSV. It appears to be the Dextrous-facing copy used to render card faces, so a text fix made only in `Cast` will not reach the card art unless `DEX Cast` mirrors it.

**Tab naming convention: an `IN ` prefix marks a tab that feeds INTO the system.** `IN Cast` is the card data the web app reads; `IN TTS` is the match data Tabletop Simulator posts in.

**The tab name is `CAST_SHEET_NAME` at the top of `webapp/main.gs`.** It has been renamed more than once (`IN CAST` -> `Cast` -> `IN Cast`), and `getSheetByName()` matches exactly — case and spacing included. If the tab is renamed, change that one constant, `clasp push`, and redeploy. `getCardDatabase()` lists every tab in the spreadsheet in its error when it can't find the configured one, so the correct name is in the error text itself.

**`getActiveSpreadsheet()` resolves to the spreadsheet the script is BOUND to, which is not necessarily the card database.** The bound sheet has imported from the DB in the past, so a tab name that exists in the DB may not exist in the sheet the script actually sees — check the bound document before assuming the error is wrong.

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
- **Every colour in `CastRecruiter.html` is a `:root` custom property, and they come in two families that must not be mixed.** Screen chrome (`--primary-colour`, `--panel-bg`, …) is the brand's off-black theme. **`--ink-*` is the printed sheet and stays light on white** — the print styles exist to save ink on home printers. The trap: the `.print-card*` rules live *outside* `@media print`, because they also render the on-screen print overlay, so you cannot keep print light by scoping the dark tokens to the `@media print` block. Use an `--ink-*` token for anything that reaches paper and a chrome token for anything that does not.
- **Run `python3 dextrous/check_theme_contrast.py` after any colour change.** It reads the tokens and both dominion maps straight out of `CastRecruiter.html` and asserts every foreground/background pair the app renders, each labelled with the rule that produces it. Two pairs are non-obvious: `--success-colour` and `--warning-colour` are the ether/specials tracker *text* as well as button fills, so they have to clear on both.
- **Dominion colours are ink, not UI.** `FACTION_COLORS` is referenced only by `generatePrintCard`, so it only ever lands on printed cards. `FACTION_PRINT_OVERRIDES` darkens the three that cannot be seen on white stock — the print grid butts cards with no gap, so a card's border is also the line you cut along.
- **Layout (Chunk 8):** `.app-shell` is a two-column grid — `.container` (max `1600px`) plus a laid-out `.status-rail` (trackers, Print, Export) that folds into a sticky row above the builder below 1100px. Card column counts are **`@container` queries on `.container`**, not viewport media queries, because the rail eats viewport width; only the phone step (<600px, one card per row) is a media query. See `UPGRADE_PLAN.md` Chunk 8 item 1 for the as-built table.
- **SVG assets are embedded by `dextrous/build_svg_sprite.py`, not pasted.** Rules text and Keywords carry icon tokens — `{Icon:{M3/Icons/Prowess/Prowess Plus 1.svg}}` or bare `{M3/Icons/Dice/Void Square.svg}` — resolving to `assets/inline icons/<type>/<file>`. The script embeds exactly the icons the CSV references (plus the footer logo) as `<symbol>`s between `SPRITE_START`/`SPRITE_END`, prefixing every internal id (the Affinity exports all reuse `_clip1`) and dropping the logo's page-wide `<style>`. **Re-run it after a re-export that uses a new icon** — `validate_cast.py` fails with "isn't in the web app yet" when one is missing. The token regex and symbol-id rule exist twice (`validate_cast.py` and `ICON_TOKEN`/`iconSymbolId` in the HTML) — change both or neither. Icons draw only in the on-screen caption (`formatRulesText(text, { icons: true })`); print, and any icon not embedded, gets `[PROWESS +1]`-style text. The header logo is the older hand-inlined `#m3-logo` sprite. Only `setFaviconUrl()` needs a real URL.

- **The brand face is Cinzel, and it is display type only.** The guide specifies one typeface (PG.07, "LOGO TYPEFACE") and no body face. `--font-display` is screen chrome; the paper-facing `.print-card*` rules keep Arial deliberately, because a webfont that fails to load must not shift a card's metrics — the print grid butts cards with no gap, so a metric shift moves the cut lines.

- **The logo is an inlined SVG sprite, and its gold is not `--accent-colour`.** Apps Script has no static asset hosting, so the lockup lives in the file as a `<symbol>` at the end of the body with a `<use>` in the header; its fill is `currentColor`. The supplied asset's gold is `#eea145` and the palette's GOLD STONE is `#E4A557` — `--logo-colour` keeps them apart on purpose. Don't reconcile them without asking Harvey.

- **The favicon can only be set from `main.gs`, never from the HTML.** Apps Script serves the page in an iframe under a Google-owned top-level document, so a `<link rel="icon">` never reaches the browser tab. `HtmlOutput.setFaviconUrl()` *fetches a URL*, so a `data:` URI will not work either — it needs a hosted file. Same trap for anything else that must reach the real tab, such as the title.

## Other repo contents

- `dextrous/` — card data JSON exports and `generate_card_images.py` for producing card art.
- `tts/` — Lua scripts for the Tabletop Simulator integration (loader, trackers, deploy scripts).
- `M3_TTS_DB - Cast.csv` at repo root — raw card data exported from the cast tab described above. The filename reflects the tab's name at export time, which has changed; the tab is currently `IN Cast`.

## Deployment

**Human-facing update steps (which script, when, why) live in `UPDATING.md` — keep it in step with any script change.**

1. Open the bound Google Spreadsheet → **Extensions > Apps Script**.
2. Copy the contents of `webapp/*.gs` and `webapp/CastRecruiter.html` into the Apps Script editor (or `clasp push` from `webapp/`).
3. **Redeploy without changing the public URL** — `clasp deploy -i <deploymentId>` repoints the
   existing deployment at a new version. The live deployment is
   `AKfycbzJ_rRo1MT81RSvWaqHqFvRzJ9utCt0stRyWUT6TguOIscMNviKVxogu8qwfqyxaBbT`; `clasp list-deployments`
   confirms it. **A plain `clasp deploy` (or Deploy > New deployment) mints a new deployment with a
   new `/exec` URL** — only do that if a new URL is actually wanted. The separate `@HEAD` deployment
   serves the `/dev` URL, which always runs the latest `clasp push` and needs no deploy step.
