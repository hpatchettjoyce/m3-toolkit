# M3 Toolkit — Upgrade Plan (single-sheet cast DB, new cards, branding)

**Created:** 2026-09-14 · **Revised:** 2026-09-14 (decisions D1–D6 folded in, see §1.1)
**Status:** Chunk 0 done (`dextrous/validate_cast.py`) — Chunk 1 is next. The validator currently
reports 4 real data gaps; see §6 item 1a.
**Source of truth for agent sessions.** Run `/pickup` to resume — it reads the latest handover note and then only the parts of this file that note points to. Don't publish this as an artifact; it stays a repo file.

---

## 1. Why this plan exists

The card database has been restructured from two sheet tabs into one, the cast list has been
re-ordered so dominions are contiguous, 25 cards have been added, and the ID scheme has changed
format. That invalidates assumptions in four separate places in the toolkit. Separately, the web
tool needs brand styling.

The work is sequenced into **8 chunks**. Each chunk is one session:

```
/pickup  ->  code  ->  summarise  ->  /handover  ->  human manually tests  ->  clear context  ->  /pickup
```

Nothing in this repo can be unit-tested locally — Apps Script needs a deploy and TTS needs the
game running — so Chunk 0 builds the one thing that *can* run offline (a CSV/deck validator), and
every later chunk leans on it before asking for a manual test.

### 1.1 Decisions already taken

Settled by Harvey on 2026-09-14, after the initial survey. **Treat these as closed** — don't re-open
them in a later session.

| # | Decision | Affects |
|---|---|---|
| D1 | The `æ`->`ae` and dropped-comma forms in `Role Details` are **intentional** Dextrous-safe transliterations, not typos. Name matching must normalise; the data is correct as-is. | §3.1, Chunk 0, Chunk 2 |
| D2 | Model health derives from the **`Class` name**. The ID changed for sorting only and **must never be parsed for meaning**. | §3.2, Chunk 1, Chunk 5 |
| D3 | `CardImages.gs` becomes an **ID-keyed map**; row-index lookups go away. | §3.3, Chunk 1, Chunk 2 |
| D4 | Effect headers render as **Lato semi-bold name, light type**, separated by `\|`. No Dextrous markup may reach the web output. *(Superseded in mechanism by D7 — the markup is gone from the data, so this is now a styling spec rather than a parsing one.)* | §3.4, Chunk 3 |
| D5 | The `Ignatious` -> `Ignatius` typo **has been fixed in the sheet**. Re-export the CSV. | §3.1, §6 |
| D6 | Deliverables stay as **repo files**. Don't publish artifacts. | all handovers |
| D7 | **Effect columns were re-split on 2026-09-14**: `Effect Name N` / `Effect Type N` / `Effect Details N`, all clean, no Dextrous markup; `Flavour Text` renamed `Flavour`. The roster is unchanged. Anything referencing `Effect 1 - Name` or `{EffectName:…}` is a stale export. | §2.2, §3.4, Chunk 0, Chunk 3 |

---

## 2. What actually changed in the data

Verified against `M3_TTS_DB - Cast.csv` and `dextrous/MonuMentuM 14-09-2026.json` on 2026-09-14.

### 2.1 One sheet, one deck

| | Old | New |
|---|---|---|
| Sheet tabs | `IN Cha-Tal` + `IN SP` | `Cast` (single) |
| CSV files | 2 | 1 — `M3_TTS_DB - Cast.csv` |
| Card rows | 176 | **200** |
| TTS saved object | `MonuMentuM Characters *.json` (80) + `MonuMentuM Specials *.json` | `MonuMentuM 14-09-2026.json` — one `Deck Cast`, **200** contained objects |

The new deck's 200 contained objects line up **1:1 and in order** with the 200 CSV rows. Its
`Nickname` and `GMNotes` are currently empty/null — nothing has been injected yet. Five
`CustomDeck` sheets (8x6 each), `DeckIDs` 100..507.

### 2.2 Columns

Old `IN Cha-Tal`: `Name (str), Dominion (str), Class (str), Role (str), ID (str), Effect (str), Combat Stats BG (int), Prowess (int), Prowess (img), Fortitude (int), Fortitude (img), Ether (int), Ether (img), Artwork (img)`

New `Cast`:

```
#, Name, Dominion, Class, Role, Role Details, ID,
Effect Name 1, Effect Type 1, Effect Details 1,
Effect Name 2, Effect Type 2, Effect Details 2,
Keywords, Ether, Prowess, Fortitude, Artwork, #Artwork Config,
Flavour, Lore, Name Inspiration, Art Direction, Mechanic(s)
```

Four changes that break code:

1. **Header suffixes dropped.** `Name (str)` -> `Name`. The backend's `findColumnIndex()` already
   accepts both spellings, so it survives; `generate_card_images.py` reads `"Name (str)"` literally
   and **will silently inject empty strings**.
2. **`Class` is now UPPERCASE.** `CHAMPION, FAMILIAR, MINION, TALISMAN, SPECIAL ACTION`. The old
   values were Title Case and the frontend does exact matches (`u.class === 'Familiar'`).
3. **`Role` is now a vocabulary, not a sentence.** Old: free text `"Flint Dross's Loyal Companion"`,
   regex-parsed. New: `COMPANION` (12), `SIGNATURE` (12), or blank (176), with the champion's
   **name** in the new `Role Details` column.
4. **`Effect` split into six columns** — name, type and details, twice over — replacing the single
   `Effect (str)`. See §3.4; the type is its own clean column, so no markup parsing is needed.

Population counts: `Effect Details 1` 197/200, `Effect Name 1` and `Effect Type 1` 90/200 each,
`Effect * 2` 7/200 each, `Keywords` 80/200, `Flavour` 60/200, `Artwork` 89/200, `Lore` 1/200.

> **Schema revised 2026-09-14 (D7).** An earlier export combined the effect name and type into a
> single `Effect 1 - Name` cell carrying `{EffectName:X} {EffectType:Y}` Dextrous markup, and called
> the flavour column `Flavour Text`. Both are gone: name and type are now separate clean columns and
> the column is `Flavour`. If you meet `Effect 1 - Name` anywhere, you're looking at a stale export.
> The card roster itself did **not** change — same 200 IDs, no additions, removals or renames.

### 2.3 Class and role census

| Class | Count | | Role | Count |
|---|---|---|---|---|
| `SPECIAL ACTION` | 102 | | *(blank)* | 176 |
| `FAMILIAR` | 68 | | `COMPANION` | 12 |
| `CHAMPION` | 12 | | `SIGNATURE` | 12 |
| `TALISMAN` | 12 | | | |
| `MINION` | 6 | | | |

### 2.4 ID format changed

`01RHA-01CHP-0001` = dominion index+code, class-order+class code, 4-digit global sequence.

**Every middle segment changed.** Old scheme had 5 segments and folded companions into `FAM` and
signatures into `SPA`; the new scheme promotes both to their own segment, which shifts all the
ordinal prefixes:

| | Old | New |
|---|---|---|
| Sequence width | 3 (`-001`) | **4 (`-0001`)** |
| Champions | `01CMP` | **`01CHP`** |
| Companions | *(folded into `02FAM`)* | **`02COM`** |
| Familiars | `02FAM` | **`03FAM`** |
| Minions | `03MIN` | **`04MIN`** |
| Talismans | `04TAL` | **`05TAL`** |
| Signatures | *(folded into `05SPA`)* | **`06SIG`** |
| Specials | `05SPA` | **`07SPA`** |

Old segment census: `05SPA` 96, `02FAM` 50, `01CMP` 12, `04TAL` 12, `03MIN` 6.
New segment census: `07SPA` 90, `03FAM` 60, `01CHP` 12, `02COM` 12, `05TAL` 12, `06SIG` 12, `04MIN` 2.

Consequence: **no existing GMNotes value on any already-injected TTS model or deck card is still
valid.** Every model must be re-run through `Model_ID_Injector.lua` after Chunk 1 — not just the
champions.

Dominion prefixes, in sheet order (now contiguous blocks of 33-34 rows):

`01RHA` Rhavlika · `02IRO` Iro-Si-Khar · `03VOI` Voisira · `04XAL` Xalakith · `05AHE` Ahèserec · `06VER` Veritian

### 2.5 The 25 new cards

24 genuinely new, 1 renamed (`Zephyr Coatl` -> `Zephyr Xoatl`).

| Dominion | New cards |
|---|---|
| Rhavlika | Caldrack, Dune-Schrag, Fissureback, Mantle Breaker |
| Iro-Si-Khar | Boisterous Dropple, Qalupel, Tempeshu, Glissade |
| Voisira | Calcytron, Hollow Kukkuhu, Sunspur, Pinion Retort |
| Xalakith | Zephyr Xoatl *(renamed)*, Xocotoc, Malefic Xoatl, Cipactin, Bonds of Fervour |
| Ahèserec | Yacupilma, Wicker Weald, Adzerin Swarm, Burgeon |
| Veritian | Fettermaw, Resonue, Fluxen, Chronatic Projection |

These need **no per-card code** — they arrive automatically once the parser reads the new sheet.
Item 3 of the brief is therefore mostly a consequence of Chunks 2-3, not separate work.

---

## 3. Findings from the survey

Seven things that will produce wrong output **silently**, rather than throwing an error. §3.1, §3.2,
§3.3 and §3.4 now have decisions attached (see §1.1) — the write-ups below record the reasoning and
the exact spec, so read them before touching the relevant chunk.

### 3.1 `Role Details` uses Dextrous-safe champion names — matching MUST normalise

`Role Details` holds the champion's name as free text, and 5 of the 24 links don't match the
champion's `Name` cell character-for-character. **These are deliberate, not typos** — Dextrous can't
take commas, and the `æ` ligature is avoided as a difficult character, so `Role Details` carries a
transliterated form of the name. A plain string lookup resolves them to `null`, which means those
loyal companions and signature actions **will not appear** for their champion.

| Card | ID | `Role Details` (Dextrous-safe) | Champion `Name` | Difference |
|---|---|---|---|---|
| Pelazhiqi | `02IRO-02COM-0037` | Tha**ela**ss Elshara | Th**æ**lass Elshara | `æ` -> `ae` |
| Ryuztli | `04XAL-02COM-0103` | Valex the Final Plume | Valex**,** the Final Plume | comma dropped |
| Kibantli | `04XAL-02COM-0104` | Micteca the Unsetting Sun | Micteca**,** the Unsetting Sun | comma dropped |
| Opolkan | `05AHE-02COM-0136` | Iroko the Evergreen | Iroko**,** the Evergreen | comma dropped |
| Egunghi | `05AHE-02COM-0137` | Draen the Ashen Hart | Draen**,** the Ashen Hart | comma dropped |

A 6th row, `Short Fuse` (`01RHA-06SIG-0018`), read `Ignatious Krag` against `Ignatius Krag`. That one
*was* a typo and **has been corrected in the sheet** — re-export the CSV to pick it up.

**Required in Chunk 2 (not optional):** resolve `Role Details` -> champion through a normalising
comparison applied to **both sides**:

1. Unicode-fold ligatures and diacritics (`æ` -> `ae`, `è` -> `e`) — NFKD decompose, strip combining
   marks, then map the ligatures NFKD leaves alone (`æ`, `œ`, `ß`).
2. Strip commas, apostrophes and periods.
3. Collapse runs of whitespace, trim, casefold.

Both sides matter: the champion's own `Name` still contains the comma and the `æ`, so normalising
only the `Role Details` side fixes nothing. Scope the match **within the dominion** — all 6 dominions
have exactly 2 champions, so a normalised collision is very unlikely, but scoping it costs nothing.

**Note for you, not a request:** the champion `Name` column still carries commas (`Valex, the Final
Plume`) and the `æ` in `Thælass Elshara`. If commas genuinely break Dextrous, those cells may hit the
same problem wherever `Name` is consumed — worth a look, but nothing in this plan depends on it.

Long term, putting the champion's *ID* in `Role Details` would remove name-matching entirely. Not
required by this plan.

### 3.2 Health must come from the Class name, not from the ID — DECIDED

`Floating_Health_Tracker.lua` currently derives a model's starting health by parsing the **middle ID
segment** (`CMP/FAM/MIN/TAL` -> Minion = 2 HP, everything else = 6 HP). That was always a proxy, and
the new ID scheme breaks it: all 12 companions carry `02COM`, but 4 of them are `MINION` class —
`Tocarin` (`02IRO-02COM-0036`), `Calazi` (`03VOI-02COM-0070`), `Opolkan` (`05AHE-02COM-0136`),
`Pashan` (`06VER-02COM-0170`) — so they'd default to 6 HP instead of 2.

**Decision (Harvey, 2026-09-14): health is derived from the `Class` name. The ID is for sorting only
and must not be parsed for meaning.** This resolves the question — the remaining work is mechanical.

Consequences for Chunk 5:

- **Delete** the `CLASS_MAP` ID-segment table and the `getModelClass()` ID-parsing function from
  `Floating_Health_Tracker.lua`, and from the copy embedded in `Model_ID_Injector.lua`. Don't update
  them for the new codes — they go away entirely. This also means **no future ID re-scheme can break
  health again**, which is the real win.
- The model needs the class name available at runtime. `Model_ID_Injector.lua` matches each model
  against a deck card, so the class has to ride along on that card: have
  `generate_card_images.py` (Chunk 1) write the card's `Class` into the deck card's `Description`,
  and have the injector read it there and stamp it onto the model. GMNotes stays exactly the plain
  ID, so every other GMNotes consumer is untouched.
- Health rule stays as it is today, just keyed off the class name: `Minion` -> 2, everything else -> 6.

Anywhere else that parses an ID segment for meaning should be treated the same way — flag it in the
handover rather than porting it to the new codes.

### 3.3 Index-keyed image mappings will scramble

`webapp/CardImages.gs` is two positional arrays, `characters[i]` and `specials[i]`, and `main.gs`
looks up art by **spreadsheet row index**. Re-ordering the cast list into dominion blocks changes
every index, so art would attach to the wrong cards. Fix in Chunk 1 by regenerating the file as a
single **ID-keyed map**.

The frontend's `champ_<index>` / `unit_<index>` / `sp_<index>` IDs are row-index-derived too. They're
internal to a page load so they don't corrupt anything, but Chunk 2 should switch them to the stable
card ID and drop the index coupling entirely.

### 3.4 Effect rendering spec — no longer a bug, just a spec

**Superseded by the 2026-09-14 schema revision (D7), and much simpler as a result.** The earlier
export packed both values into one cell as `{EffectName:SMOLDER} {EffectType:| *FREE ACTION*}`, which
`formatRulesText()`'s catch-all `html.replace(/\{.*?\}/g, '')` would have stripped to nothing. That
bug is **gone**: name and type are now separate, clean columns with no markup, no asterisks and no
pipe.

Render as:

> **SMOLDER** | FREE ACTION

with the name in **Lato semi-bold (600)** and the type in **Lato light (300)**.

| Column | Example value | Web rendering |
|---|---|---|
| `Effect Name N` | `SMOLDER` | `<span class="effect-name">` — Lato 600 |
| `Effect Type N` | `FREE ACTION` | `<span class="effect-type">` — Lato 300 |
| `Effect Details N` | prose with `**BOLD**` / `*italic*` / `{M3/Icons/…}` | existing `formatRulesText()` |

Details that matter:

- **The renderer supplies the `|` separator.** It used to live inside the data; it doesn't any more.
- Name and type are always populated together — 90 cards have effect 1, 7 also have effect 2.
- **`Effect Type` is a closed 10-value vocabulary**, all caps, verified across all 200 rows:
  `ABILITY` (60), `ACTION` (15), `ATTACK ACTION` (4), `FREE ACTION` (8), `FREE ATTACK REACTION` (4),
  `MANOEUVRE ACTION` (2), `ATTACK EXERTION` (1), `ATTACK MANOEUVRE ACTION` (1),
  `FREE ATTACK ACTION` (1), `SPECIAL ACTION` (1). Chunk 0 should validate against this list — an
  unexpected value means a data-entry slip, not a new category.
- **`formatRulesText()` still needs its curly-token rules** — but only for `Effect Details` and
  `Keywords`, which carry icon tokens like `{M3/Icons/Dice/SQUARE.png}` (46 cells). The existing
  rules already convert those to `<strong>[SQUARE]</strong>` **before** the catch-all, so this path
  works today. Don't remove it; just don't let it near the name/type columns, which need no parsing.
- Lowercase `manoeuvre` in `Effect Details` is **correct prose** (`When an enemy performs a
  *manoeuvre*...`) and must be left alone. Only the `Effect Type` labels are all-caps.
- **Lato is a font dependency** (Google Fonts). It overlaps Chunk 7's typography work — load the two
  weights in Chunk 3 and let Chunk 7 extend the stack rather than redo it. Declare a real fallback.

Two things this revision also cleared, recorded so nobody hunts for them: the `Cinderhulk` lowercase
casing artifact is **fixed** (`ATTACK MANOEUVRE ACTION`), and the trailing per-effect cost that used
to ride inside two type payloads (`| 4` on `Lark` and `Pashan`) is **gone** — both cards' effects
were rewritten.

### 3.5 Two TTS zones become one

`TTS_Loader.lua` reads a characters deck and a specials deck from two separate scripting zones
(`CHARACTERS_ZONE_GUID`, `SPECIALS_ZONE_GUID`). With one merged deck this becomes one zone. That's
a **physical table change as well as a code change** — you'll need to place the single Cast deck and
point one zone at it. Chunk 4.

### 3.6 Branding assets are not reachable

`G:\My Drive\...\M3 Branding Guide.pdf` can't be read from this environment — WSL only has `/mnt/c`
mounted, no `/mnt/g`.

**Action for you before Chunk 6:** copy the PDF and the logo PNGs into `assets/branding/`. From
Windows Explorer, paste this into the address bar:

```
\\wsl.localhost\Ubuntu\home\harvey\projects\m3-toolkit\assets\branding
```

(On older Windows builds the prefix is `\\wsl$\Ubuntu\...` instead.) The repo itself is at
`\\wsl.localhost\Ubuntu\home\harvey\projects\m3-toolkit`, which is worth pinning to Quick Access.

If Explorer can't find the folder, just create it by hand — nothing depends on how it gets there.

If pasting into WSL is awkward, `G:\` can instead be mounted so future sessions can read Drive
directly: `sudo mkdir -p /mnt/g && sudo mount -t drvfs G: /mnt/g` (add it to `/etc/fstab` to persist).
Optional — the copy-in route is enough for this plan.

### 3.7 Hardcoded old-format IDs

Grep hits in `tts/TTS_Loader.lua`: `01RHA-01CMP-001`, `02IRO-01CMP-005`, `03VOI-01CMP-010` (onboarding
scenario casts) and `02IRO-03MIN-009`, `05AHE-03MIN-022` (auto-summon minion pools). New values:

| Old | New | What |
|---|---|---|
| `01RHA-01CMP-001` | `01RHA-01CHP-0001` | Flint Dross |
| `02IRO-01CMP-005` | `02IRO-01CHP-0034` | Ripple Elshara |
| `03VOI-01CMP-010` | `03VOI-01CHP-0068` | Lark |
| `02IRO-03MIN-009` | `02IRO-04MIN-0048` | Driplet |
| `05AHE-03MIN-022` | `05AHE-04MIN-0148` | Huskling |

The `CMP/FAM/MIN/TAL` segment map also appears in `Floating_Health_Tracker.lua` **and** is duplicated
inside `Model_ID_Injector.lua` (which embeds the tracker source). Per **D2** both copies are
**deleted**, not updated — see §3.2. These five IDs in `TTS_Loader.lua` are genuine identifiers being
looked up, not parsed for meaning, so they do just need the new values.

---

## 4. Chunks

Dependency order. **0 -> 1 -> 2 -> 3** is a hard chain (each needs the previous). **4 -> 5** is a
second chain that needs 1. **6 -> 7** (branding) touches only `CastRecruiter.html` styling and is
independent — run it any time, including first if you'd rather see progress on the look early.

```
0 ── 1 ─┬─ 2 ── 3          (data pipeline -> backend -> frontend)
        └─ 4 ── 5          (TTS loader -> models/health)
   6 ── 7                  (branding, independent)
```

---

### Chunk 0 — Validation harness

**Goal:** one offline script that proves the data is sane, so later chunks have a real test.

- Add `dextrous/validate_cast.py`. No behaviour change to anything shipping.
- Checks: row count; `ID` unique and well-formed; dominion prefix agrees with the `Dominion` column;
  dominion blocks contiguous; `Class` in the 5-value vocabulary; `Role` in
  `{COMPANION, SIGNATURE, ""}`; every `COMPANION`/`SIGNATURE` row has `Role Details`; **every
  `Role Details` resolves to a champion in the same dominion under the §3.1 normalised
  comparison**; every non-companion/signature row has empty `Role Details`; `Effect Type N` is in
  the closed 10-value vocabulary from §3.4; `Effect Name N` and `Effect Type N` are populated
  together (neither alone); **no effect name/type cell contains `{` or `*`** — that would mean a
  stale export with the old Dextrous markup; deck JSON `ContainedObjects` count == CSV row count;
  `DeckIDs` length matches; every `CustomDeck` sheet referenced exists.
- **Check the header row against the expected column list** (§2.2) and fail with a clear message if
  it doesn't match. The schema has now moved twice; a validator that silently reads the wrong columns
  is worse than one that refuses.
- **Write the normalising name-match here, as a reusable function**, and port the same logic into
  `main.gs` in Chunk 2. Two implementations that disagree is the failure mode to avoid — if the
  validator passes but the web app drops a link, this is the first place to look.
- The validator must **not** treat the §3.1 transliterations as errors. `æ`->`ae` and dropped commas
  are intentional Dextrous-safe forms; they must resolve cleanly. Only a name that fails to resolve
  *after* normalisation is a failure.
- Exit non-zero with a readable report on failure.

**Test:** `python3 dextrous/validate_cast.py`.

**Status: done 2026-09-14.** `dextrous/validate_cast.py` implements every check above, plus three
the survey implied: the global sequence and `#` column must agree with row position, and the middle
ID segment must agree with the authoritative `Role`/`Class` columns (a consistency check on the ID,
not deriving meaning from it — D2 stands). `normalise_name()` is the reusable function Chunk 2 ports
into `main.gs`. Teeth verified by corrupting a copy of the CSV: a broken `Role Details`, a stale
`Effect 1 - Name` header, a split dominion block, an unknown effect type and a `{EffectName:…}` cell
are each reported, and every corruption exits 1. A naive exact match fails exactly the 5 rows in
§3.1; under normalisation all 24 links resolve.

**Outstanding:** the validator exits 1 on the current data because of 4 genuine missing effect
name/type cells — §6 item 1a. Everything else is clean.

**Done when:** it passes clean on the current data — all 24 companion/signature links resolving,
including the 5 transliterated ones. To confirm the link check actually has teeth rather than
passing vacuously, temporarily corrupt one `Role Details` value and check it's reported, then revert.

---

### Chunk 1 — Rewrite the compiler (`generate_card_images.py`)

**Goal:** one CSV + one deck JSON in, ID-keyed `CardImages.gs` + injected deck JSON out.

- Read `M3_TTS_DB - Cast.csv` (single file; drop the `IN Cha-Tal`/`IN SP` pair) using the new
  unsuffixed headers.
- Read the newest `MonuMentuM *.json` by glob — note the new name has no `Characters`/`Specials`
  qualifier, so the existing two-pattern glob must collapse to one.
- Inject `Nickname` = `Name` and `GMNotes` = `ID` into all 200 contained objects. Keep the
  `SYN-` synthetic-ID fallback for blank IDs, but the validator should mean it never fires.
- **Bail out loudly if the deck's object count != the CSV row count.** The whole injection is
  positional; a mismatch must not be allowed to write a silently-shifted deck.
- Emit `webapp/CardImages.gs` as a single **ID-keyed map**, replacing the two positional arrays:
  ```js
  function getCardImageMappings() {
    return {
      cards: {
        "01RHA-01CHP-0001": { url: "...", cols: 8, rows: 6, idx: 0 },
        ...
      }
    };
  }
  ```
  Keep the function name `getCardImageMappings` — `main.gs` calls it and the flat GAS namespace makes
  renames risky.
- **Write each card's `Class` into the deck card's `Description`.** Chunk 5 needs it there to set
  model health from the class name instead of parsing the ID (§3.2). Doing it here means Chunk 5
  doesn't have to come back and re-run the compiler.

**Test:** run the script; confirm 200 entries in `CardImages.gs`, 200 injected `Nickname`/`GMNotes`,
and 200 `Description` values carrying the class; import the deck into TTS and hover a few cards from
different dominions to confirm names and art line up.

**Done when:** script runs clean on the new data, `CardImages.gs` is ID-keyed with 200 cards, and the
deck imports into TTS with correct hover names.

---

### Chunk 2 — Rewrite `getCardDatabase()` in `main.gs`

**Goal:** the backend serves all 200 cards from the single tab, with the existing JSON contract intact.

- `CHAR_SHEET_NAME` + `SP_SHEET_NAME` -> a single `CAST_SHEET_NAME = "Cast"`. Leave
  `MATCH_SHEET_NAME = "IN TTS"` alone — the webhook is unaffected.
- Single pass over the new columns. Keep the two-pass structure (champions first, then everything
  else) since links still resolve against champions.
- **Normalise `Class` to Title Case** (`CHAMPION`->`Champion`, `SPECIAL ACTION`->`Special Action`).
  This keeps `CastRecruiter.html` and the TTS-facing contract working unchanged, and is much lower
  risk than changing every comparison in a 1734-line frontend file. Do the normalisation once, in a
  helper, at the parse boundary.
- Replace the two `Role` regexes with direct checks: `isLoyal = Role === 'COMPANION'`,
  `isSignature = Role === 'SIGNATURE'`, and resolve `tiedChampionId` from `Role Details` via the
  **normalising** name match from §3.1. Log a warning for unresolved links.
- Route `MINION`-class companions into `db.units` as before — they're companions that happen to be
  minions, and the frontend already handles `class === 'Minion'` in its basics filter.
- Look art up by card ID against the new `cards` map; drop `imageMappings.characters[index]`.
- Use the card ID for `db.champions[].id` / `units[].id` / `specials[].id` instead of `champ_<index>`
  etc. Keep `uniqueId` populated too so the roster import/export paths keep working unchanged.
  **`tiedChampionId` must then also be the champion's card ID** — the frontend compares it directly
  against `state.champion` (line ~917 for loyals, ~1161 for signatures), so the two must use the same
  key space or every link silently fails.
- Pass through the new fields: `effect1Name`, `effect1Details`, `effect2Name`, `effect2Details`,
  `keywords`, `flavourText`, `artwork`. Keep a legacy `effect` key (effect 1 details) so the frontend
  keeps rendering while Chunk 3 is still pending — that's what makes this chunk independently testable.
- Keep the closing `JSON.parse(JSON.stringify(db))` sanitiser.
- **Do not** add a second card-fetching function in another `.gs` file (see `CLAUDE.md` — flat global
  namespace; this has bitten the project before).

**Test:** `clasp push` from `webapp/`, open the web app. For each of the 6 dominions: champion list
populates, basics list populates, talismans appear, signature actions show under the right champion,
loyal companions show under the right champion. Confirm the new cards from §2.5 are present. Confirm
card art still loads.

**Done when:** all 6 dominions build a legal cast end to end, and the 6 companion/signature links
from §3.1 resolve.

---

### Chunk 3 — Frontend: new effect model and new fields

**Goal:** the web tool renders the richer card data properly.

- Render the effect header per §3.4: `Effect Name N` in Lato 600, then a renderer-supplied `|`, then
  `Effect Type N` in Lato 300. **No token parsing** — these columns are clean (D7). Pass
  `Effect Details N` through `formatRulesText()` as before.
- Leave `formatRulesText()`'s existing curly-token rules alone: `Effect Details` and `Keywords` still
  carry `{M3/Icons/…}` tokens (46 cells), and the existing rules already convert them ahead of the
  `\{.*?\}` catch-all. Keep the `escapeHtml()`-first ordering — sheet text must stay inert (see
  `CLAUDE.md`).
- Load Lato 300 and 600 from Google Fonts with a real fallback stack. Chunk 7 extends this; don't
  let it redo it.
- Render effect 1 and effect 2 as separate blocks in both the browser card view and the print card.
  Only 7 cards have a second effect, so the layout must collapse cleanly when it's absent.
- Surface `Keywords` (80/200 cards) and, if there's room, `Flavour` (60/200).
- Re-check the print card layout: it's pinned to poker size (63.5mm x 88.9mm) in a 3x3 A4 grid, so
  two effects plus keywords is a real space constraint. Shrinking type is fine; breaking the 3x3
  page grid is not.
- Verify the auto-minion injection and the `cost > 0` recruitability guard still behave: `Driplet`
  and `Huskling` have **blank** Ether, which `parseInt('') || 0` turns into 0, so they stay out of
  the recruitable basics list. Confirm rather than change.

**Test:** manual walkthrough of all 6 dominions; specifically open `Caldrack` (`01RHA-03FAM-0012`),
which has both effects populated — expect `CAUSTIC ANTLERS | ABILITY` and
`VITRIOLIC QUENCH | FREE ACTION`. Check a card whose details carry an icon token, e.g. `Fissureback`
(`01RHA-03FAM-0014`), renders `[SQUARE]` rather than a raw `{M3/Icons/…}` string. Confirm no stray
`{`, `}` or `*` characters appear anywhere. Then print-preview a full cast and check the 3x3 A4
pages still break correctly and nothing clips.

**Done when:** effect names render in semi-bold with their type in light, icon tokens still resolve,
two-effect cards look right, and print preview is unbroken.

---

### Chunk 4 — TTS loader: one deck, new IDs

**Goal:** `TTS_Loader.lua` loads rosters from the single Cast deck.

- `CHARACTERS_ZONE_GUID` + `SPECIALS_ZONE_GUID` -> one `CAST_ZONE_GUID`. Update the instruction
  comment block at the top of the file (it tells the user to make two zones).
- Collapse `findDecks()` (line ~622, which calls `getDeckFromZone()` twice) to a single lookup, and
  retire the `isSpecial` parameter threaded through `cloneCardFromDeck()` (line ~637, branching at
  ~657 and ~702) — there's one deck now, so the specials/characters split in the lookup path goes
  away. Keep the collision-free teleportation return physics exactly as-is; it's load-bearing and
  hard-won.
- `loadCastCoroutine()` (line ~341) is the caller that walks champion -> familiars -> talismans ->
  specials against the two decks; its lock-release-on-every-exit-path behaviour must survive the edit.
- Update the 5 hardcoded IDs per the table in §3.7.
- Re-verify the onboarding scenario cast lists still name real cards under the new IDs.
- Keep `getMatchDataJson()` and the specials log intact — `End_Game_Controller.lua` calls across
  scripts and the webhook contract shouldn't move in this chunk.

**Test:** in TTS, place the single Cast deck, point the zone at it, then load a roster for each
dominion. Check: champion card dealt, familiars dealt, talismans dealt, specials dealt, standees
spawn in the right grid rows, and the Iro-Si-Khar / Ahèserec 12-minion pools still stack. Run one
reduced scenario (1 or 2) to confirm champions and minions are still correctly suppressed.

**Done when:** a full roster and a reduced scenario both load cleanly from the merged deck.

---

### Chunk 5 — Model ID Injector + Floating Health Tracker

**Goal:** models get correct IDs and correct default health under the new ID scheme.

§3.2 is already decided: **health comes from the `Class` name, and the ID is never parsed for
meaning.** So this chunk removes logic rather than porting it.

- **Delete** `CLASS_MAP` and `getModelClass()` from `Floating_Health_Tracker.lua` and from the copy
  embedded in `Model_ID_Injector.lua`. Do not update them to the new segment codes.
- Read the class from the model instead, stamped by the injector from the deck card's `Description`
  (written in Chunk 1). Health rule unchanged: `Minion` -> 2, everything else -> 6.
- Decide and record how the class reaches the model at runtime — the injector can either write it
  onto the model (its own `Description`, which it currently clears) or bake the resolved starting
  health straight into the injected script. Baking the number in is simpler; writing the class keeps
  the model self-describing for later tools. Note the choice in the handover either way.
- Delete the now-stale ID-format comments in both files (they cite `01RHA-02FAM-002` and explain the
  segment-parsing that's going away).
- The tracker's shape check (`self.tag == "Tile"`) is independent of card class — leave it alone.
- **Grep both files for any other ID-segment parsing** before finishing. Anything else deriving
  meaning from an ID should be reported in the handover, not quietly ported to the new codes.

**Test:** run the injector against the merged Cast deck and the models bag. Confirm each model's
GMNotes carries a new-format ID, names are cleaned of trailing costs (`Obduron (6)` -> `Obduron`),
and the floating dial appears. Then specifically check health defaults: a champion (6), a familiar
(6), `Driplet` (2), and `Tocarin` (2 — the case the old logic would get wrong).

**Done when:** all four health cases above are correct.

---

### Chunk 6 — Branding pass 1: colour system and dark theme

**Prerequisite:** `assets/branding/M3 Branding Guide.pdf` copied into the repo (see §3.6).

**Goal:** the web tool uses the brand palette on an off-black ground.

- Extract the palette from the brand guide and define it as CSS custom properties. The `:root` block
  currently has 9 tokens but the file carries ~30 hardcoded hexes — tokenise the stragglers first, as
  a no-visual-change step, so the theme swap afterwards is a small diff.
- Apply the off-black background and re-derive panel, border, and text tokens for adequate contrast.
  Check the `--warning-colour` / `--success-colour` pair still reads against the dark ground.
- Re-map `FACTION_COLORS` (currently `#c0392b`, `#2980b9`, `#b7950b`, `#7d3c98`, `#27ae60`, `#138d75`)
  to the brand's dominion colours if the guide specifies them. They're used for both on-screen accents
  and the low-ink print borders.
- **Keep `@media print` light-on-white.** The print styles exist to save ink on home printers; an
  off-black background must not leak into them. The print block starts at roughly line 503 — scope the
  dark tokens so they don't apply there.
- Keep the responsive breakpoints (1100/900/600px) and the 1200px container intact.

**Test:** open the web app and walk one full cast build. Check contrast on every panel, the dominion
picker, the cost readouts, and the warning/success states. Then print-preview and confirm the pages
are still light with coloured borders.

**Done when:** the app reads as branded dark, and print preview is unchanged from before the chunk.

---

### Chunk 7 — Branding pass 2: logos and typography

**Prerequisite:** logo PNGs in `assets/branding/`.

**Goal:** identity, not just colour.

- Header logo, favicon, and a page title treatment. Note the app is served by Apps Script
  `HtmlService` as a single file — external images need reachable URLs (Drive thumbnail links are
  already used for card art, per the `Artwork` column) or base64 inlining. Inlining keeps it
  self-contained but inflates a file that's already 1734 lines; prefer hosted URLs unless the logos
  are small.
- Brand typography if the guide specifies faces. Always give a real fallback stack — the current
  `'Segoe UI', Tahoma, Geneva, Verdana, sans-serif` is a reasonable base to extend.
- Consider a logo on the print card back or footer, but weigh it against the low-ink goal.

**Test:** visual check at desktop, 900px and 600px widths. Print-preview once more.

**Done when:** the tool is recognisably Monumentum-branded at all three widths.

---

## 5. Handover protocol

### 5.1 The point of the handover

Each chunk is one session, and the session gets **cleared** between chunks. The handover note is
what makes that safe: it **compresses a spent context window** into something a fresh session can
read in a few seconds and then start working, without re-exploring the codebase or re-deriving what
the last session worked out.

So the note is a compression job, not a record-keeping one. The test for every line is *would the
next session have to redo work without this?* Roughly 60–150 lines. Cite `file.ext:120` rather than
pasting code; cite a section of this plan rather than restating it. Spend the length on **gotchas** —
they're the part that can't be re-derived cheaply.

### 5.2 Where notes live

**Central store, outside this repo:**

```
~/.claude/handovers/m3-toolkit/<YYYY-MM-DD>_<HHMM>__<nn>-<slug>.md
```

The date prefix sorts chronologically, so "most recent" is a plain sort. Each note carries
frontmatter (`project`, `date`, `unit`, `status`, `branch`, `commit`, `next`, `tags`) so a note can
be found by chunk number, date or keyword.

They're deliberately **not** in the repo: a handover is about the *session*, not the codebase, and it
should survive branches and worktrees being deleted. The consequence is that notes aren't versioned
or shared — which is why **this section, in the repo, is the specification**. The skills automate it;
they don't define it. If they're unavailable, follow §5.1–§5.4 by hand and nothing is lost.

### 5.3 The two commands

| Command | What it does |
|---|---|
| `/pickup` | Reads the most recent note for this project, then reads **only** what the note points to, verifies the repo state cheaply, checks your §6 prerequisites, orients you, and starts the chunk. An argument selects a different note: `/pickup 3`, `/pickup branding`, `/pickup list`. |
| `/handover` | Gathers the git facts by running commands rather than recalling them, writes the note to the central store, commits the code, then gives you the manual test steps. Amends the note with the result once you report back. |

**Start each session with `/pickup`, end it with `/handover`.** Both are user-level skills
(`~/.claude/skills/`) and work in any project.

### 5.4 What goes in a note

Frontmatter, then: **What changed** (per file, one line each) · **Decisions** (with reasons and what
they rule out) · **Verified** (what you ran and its result, kept separate from what you only expect)
· **Not done** (and where the seam is, if partial) · **Gotchas** · **Next session starts here** (a
concrete first action, plus which sections or line ranges to read).

Write "None" rather than dropping a heading, so "nothing to report" is distinguishable from "not
considered".

Rules that keep this working:

- **Write the note before the manual test, then amend it after.** If the test fails, that failure
  detail is the most valuable thing in the file.
- **Separate verified from assumed.** A confident-sounding unverified claim is the most expensive
  thing you can leave behind.
- Record decisions and their *reasons*. Git already has the diffs.
- If a chunk ends partial, say exactly where the seam is.
- **Update this plan's §1–§3 if a finding turns out to be wrong.** Later sessions trust it.

### 5.5 Git policy — work on `main`

**One commit per chunk, on `main`, pushed.** That commit *is* the rollback point for the chunk,
which is the whole reason the work is chunked.

- **No feature branches, no worktrees.** Tried on the planning pass and it cost more than it gave:
  the same CSV drifted in two places at once, `UPGRADE_PLAN.md` was invisible in the working
  checkout, and the merge back was blocked by untracked files. A branch adds a merge to get wrong
  and hides the work in the meantime.
- Never force-push or rewrite pushed history — the rollback points only work if they stay put.
- Commit the user's own data re-exports too (CSV, deck JSON) as they arrive, so the input a chunk
  compiled against is recoverable.
- **Before touching a modified input file, check whether it's newer than the committed copy.** This
  bit twice during planning: the `Cast` CSV and the deck JSON were both re-exported mid-session, and
  acting on the stale assumption would have destroyed the newer data.

Note for background sessions only: they're force-isolated into a worktree unless the project sets
`"worktree": {"bgIsolation": "none"}` in `.claude/settings.local.json`. Interactive sessions are
unaffected.

---

## 6. Actions for you (not code)

1. ~~**Re-export the `Cast` CSV**~~ — **done 2026-09-14**, twice. The `Ignatious` -> `Ignatius` fix,
   the `MANOEUVER` -> `MANOEUVRE` spelling correction, and the D7 effect-column re-split are all in.
   The copy committed on `main` matches your working copy. The 5 `Role Details` name variants
   are intentional and need no change.
2. ~~**Fix the `Cinderhulk` effect-type casing**~~ — **done**, arrived with the D7 re-export as
   `ATTACK MANOEUVRE ACTION`.
1a. **Fill in 4 missing effect name/type cells** — found by the Chunk 0 validator, all in the
   Veritian block. `Effect Name N` and `Effect Type N` must be populated together (§3.4); these four
   rows have one without the other:

   | Sheet row | ID | Card | Missing |
   |---|---|---|---|
   | 170 | `06VER-01CHP-0169` | Clement Tacitus | `Effect Name 1` (type is `FREE ACTION`) |
   | 176 | `06VER-03FAM-0175` | Occulacer | `Effect Type 1` (name is `STINGING TENTACLES`) |
   | 177 | `06VER-03FAM-0176` | Hastaca | `Effect Name 1` (type is `ABILITY`) |
   | 185 | `06VER-06SIG-0184` | Apertures of Mirimara | `Effect Type 1` (name is `JUMP START`) |

   Fill them in the sheet and re-export the CSV. **This does not block Chunk 1** — it affects the
   rendered header on 4 cards only. Until it is fixed `validate_cast.py` exits 1, so later chunks
   should read the report rather than just the exit code.

3. **Copy the branding assets** into `assets/branding/` — the PDF and the logo PNGs. Path and
   Explorer instructions are in §3.6. Needed before Chunk 6. **This is now the only outstanding
   prerequisite, and it only blocks Chunks 6–7.**
4. **Plan the TTS table change** for Chunk 4: one Cast deck, one scripting zone over it.
5. *(Optional)* **Check whether commas in the champion `Name` column cause trouble in Dextrous**
   (§3.1). `Valex, the Final Plume` and `Thælass Elshara` still carry the characters that
   `Role Details` avoids. Nothing in this plan depends on it.
6. *(Optional)* **Consider putting champion IDs in `Role Details`** instead of names, which would
   remove name-matching entirely.

## 7. Clean-up deferred to the end

Once Chunks 0-5 are verified, delete the superseded inputs:
`M3_TTS_DB - IN Cha-Tal.csv`, `M3_TTS_DB - IN SP.csv`,
`dextrous/MonuMentuM Characters 08-06-2026.json`, `dextrous/MonuMentuM Specials 08-06-2026.json`,
and the stray `*:Zone.Identifier` files. Then update `CLAUDE.md` and `PROJECT_NOTES.md` — both
document the two-tab architecture throughout and will be actively misleading after Chunk 2.
