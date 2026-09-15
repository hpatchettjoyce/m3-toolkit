# M3 Toolkit — Upgrade Plan (single-sheet cast DB, new cards, branding)

**Created:** 2026-09-14 · **Revised:** 2026-09-14 (decisions D1–D6 folded in, see §1.1)
**Status:** Chunks 0, 1 and 2 done and **verified in the browser** — Chunk 4 is next (Chunk 3 is
withdrawn, D11). The validator passes clean, the compiler emits an ID-keyed `CardImages.gs` with all
200 cards, and `main.gs` serves all 200 from the single `IN Cast` tab with art looked up by card ID.
Deployed 2026-09-15 as **@17** to the existing deployment id, so the public URL is unchanged.
**Still untested:** roster export / re-import, the path most exposed to the `champ_<index>` -> card-ID
change.
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
| D4 | ~~Effect headers render as **Lato semi-bold name, light type**~~. *(Superseded in mechanism by D7, then **withdrawn entirely by D11** — the web app renders card images, so there is no web effect styling to spec. The "no Dextrous markup reaches the output" half is now enforced by `validate_cast.py` instead.)* | §3.4, Chunk 3 |
| D5 | The `Ignatious` -> `Ignatius` typo **has been fixed in the sheet**. Re-export the CSV. | §3.1, §6 |
| D6 | Deliverables stay as **repo files**. Don't publish artifacts. | all handovers |
| D11 | **The web app renders card *images*, not effect text — Chunk 3 is withdrawn.** The browser view already paints the sprite-sheet card face, and print preview is a deliberately plain, printer-friendly text card that is staying that way. No effect styling work is needed; the one real requirement (don't lose effect text that used to print) folds into Chunk 2. | §3.4, Chunk 2, Chunk 3 |
| D10 | **An effect may carry an ether cost, written `\| N` at the end of `Effect Type N`** — `SPECIAL ACTION \| 4`. This is a *per-effect* cost, distinct from the card-level `Ether` column: Lark is a CHAMPION with a blank `Ether` whose `TRICK SHOT` still costs 4. **A `SPECIAL` always has one**, and the validator enforces that. | §3.4, Chunk 0, Chunk 2 |
| D9 | **Effect types are validated as a grammar, not a list.** `ABILITY`, or `[FREE\|SPECIAL] ACTION/ATTACK/MANOEUVRE/ATTACK MANOEUVRE [REACTION/EXERTION]`, either optionally followed by an ether cost (D10) — brackets optional, slashes either/or. A closed list broke on every vocabulary tweak; the grammar accepts new legal combinations without a code change. | §3.4, Chunk 0, Chunk 2 |
| D8 | **Effect-type vocabulary trimmed on 2026-09-14**: the redundant trailing `ACTION` is dropped wherever the type already implies one — `ATTACK ACTION` -> `ATTACK`, `MANOEUVRE ACTION` -> `MANOEUVRE`, `ATTACK MANOEUVRE ACTION` -> `ATTACK MANOEUVRE`, `FREE ATTACK ACTION` -> `FREE ATTACK`. An attack *is* an action unless it is a reaction. `ACTION`, `FREE ACTION`, `SPECIAL ACTION` and `REACTION` keep the word. Same re-export fixed the misaligned effect rows. | §2.2, §3.4, Chunk 0, Chunk 2 |
| D7 | **Effect columns were re-split on 2026-09-14**: `Effect Name N` / `Effect Type N` / `Effect Details N`, all clean, no Dextrous markup; `Flavour Text` renamed `Flavour`. The roster is unchanged. Anything referencing `Effect 1 - Name` or `{EffectName:…}` is a stale export. | §2.2, §3.4, Chunk 0, Chunk 2 |

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

Population counts (after the D8 re-export): `Effect Details 1` 197/200, `Effect Name 1` and
`Effect Type 1` **84/200** each, `Effect * 2` 7/200 each, `Keywords` 80/200, `Flavour` 60/200, `Artwork` 89/200, `Lore` 1/200.

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
Item 3 of the brief is therefore mostly a consequence of Chunk 2, not separate work.

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

**Resolved in Chunk 5 (2026-09-15). How the class reaches the model: the injector stamps it onto the
model's own `Description`**, which it previously blanked. Chosen over baking the resolved number into
the injected script because it keeps models self-describing for later tools, and because a health
rule change then needs no re-injection of 200 models. `GMNotes` stays the plain ID. Note the deck
writes the class in **upper case** (`MINION`), so the comparison is case-insensitive.

**"Every health tracker reads 6" (Harvey, TTS, 2026-09-15) — cause: the models carried no class.**
Two earlier explanations were both wrong and are recorded so they are not retried. (a) The predicted
"only 4 cards fail" was wrong — Harvey confirms *every* minion read 6, including `Driplet` and
`Huskling`, which the old `MIN` parsing should have got right. (b) A later guess that minions simply
had not spawned (because `Driplet`/`Huskling` only appear for Iro-Si-Khar and Ahèserec,
`TTS_Loader.lua:503,559`) was also wrong — Harvey confirms minions did load.

The real mechanism is that the model has no class on it at all: before Chunk 5 the injector
**blanked** each model's `Description` and the tracker parsed the ID instead, so anything the ID
parse missed fell back to `DEFAULT_HEALTH = 6`. Chunk 5 stamps the class on and reads it from there.
**That requires both a re-imported Cast deck (so cards carry the class) and a re-injection (so models
carry it) before any minion reads 2.** `checkClassCoverage()` in `Model_ID_Injector.lua` now warns
loudly when the deck is stale, because this failure is otherwise completely silent.

Also found and removed: `CLASS_CODES` mapped `CMP`, but champions actually use `CHP`, so that entry
never matched anything in the deck's history.

**`Fortitude` is NOT health — settled by Harvey, 2026-09-15.** `Fortitude` is a character's
**defense** and `Prowess` is its **strength**; an attack compares strength against defense, which is
what lets starting health be normalised to a flat value. So `Minion -> 2, everything else -> 6` is
the intended rule, not an approximation of a per-card number. **Do not "improve" this by reading
`Fortitude` (or `Prowess`) into the health tracker** — a previous session proposed exactly that from
the CSV alone and was wrong. Neither stat is hit points.

### 3.3 Index-keyed image mappings will scramble

`webapp/CardImages.gs` is two positional arrays, `characters[i]` and `specials[i]`, and `main.gs`
looks up art by **spreadsheet row index**. Re-ordering the cast list into dominion blocks changes
every index, so art would attach to the wrong cards. Fix in Chunk 1 by regenerating the file as a
single **ID-keyed map**.

The frontend's `champ_<index>` / `unit_<index>` / `sp_<index>` IDs are row-index-derived too. They're
internal to a page load so they don't corrupt anything, but Chunk 2 should switch them to the stable
card ID and drop the index coupling entirely.

### 3.4 Effect data spec — and why the web app no longer styles it

**Two revisions have reshaped this section.** D7 split name and type into separate clean columns,
removing a real parsing bug. **D11 then withdrew the web-styling half entirely**: the browser view
paints the sprite-sheet card image, and effect text appears in exactly one place —
`formatRulesText(card.effect)` at `webapp/CastRecruiter.html:1466`, inside the print card.

So what follows is a **data** spec. It governs three consumers, none of which is web styling:

1. **`validate_cast.py`** — the grammar and cost rules below are enforced there.
2. **The Dextrous card faces** — the card art *is* the rendering; these columns are what Dextrous
   prints onto it.
3. **The print card** — a plain, printer-friendly text card. It needs the text, not the styling.

The old bug, recorded so nobody re-fixes it: the pre-D7 export packed both values into one cell as
`{EffectName:SMOLDER} {EffectType:| *FREE ACTION*}`, which `formatRulesText()`'s catch-all
`html.replace(/\{.*?\}/g, '')` would have stripped to nothing. Gone — name and type are separate,
clean columns with no markup, no asterisks and no pipe.

Render as:

> **SMOLDER** | FREE ACTION

A costed effect (D10) carries a third part, so `TRICK SHOT` + `SPECIAL ACTION | 4` reads:

> TRICK SHOT | SPECIAL ACTION | 4

**On the card face** that is Dextrous's job. **On the print card** it is one plain-text line that
Chunk 2 composes into the legacy `effect` string — no spans, no font weights (D11).

| Column | Example value | Where it goes |
|---|---|---|
| `Effect Name N` | `SMOLDER` | first part of the composed header line |
| `Effect Type N` | `FREE ACTION` | second part, ` | `-separated |
| `Effect Type N` cost part | `4` in `SPECIAL ACTION \| 4` | already inside the cell — print it as-is; no need to split it out |
| `Effect Details N` | prose with `**BOLD**` / `*italic*` / `{M3/Icons/…}` | existing `formatRulesText()`, unchanged |

Details that matter:

- **Whoever composes the header supplies the `|` between name and type.** That separator used to
  live in the data and doesn't any more — but **the cost's own `|` does live in the data** (D10), so
  a costed header ends up with two bars and only the first is composed. For the print card that is
  fine: both are literal text.
- Name and type are always populated together — 90 cards have effect 1, 7 also have effect 2.
- **`Effect Type` follows a grammar** (D9), all caps:

  ```
  ABILITY
  [FREE | SPECIAL] ACTION | ATTACK | MANOEUVRE | ATTACK MANOEUVRE [REACTION | EXERTION]  [| N]
  ```

  Brackets mark optional parts, slashes either/or, exactly one space between parts.
  `validate_cast.py` enforces this shape rather than a fixed list, so a legal combination that
  hasn't been used yet — `FREE MANOEUVRE`, say — passes without a code change. Observed values as
  of the D8 re-export: `ABILITY` (54), `ACTION` (15), `FREE ACTION` (8), `ATTACK` (4),
  `FREE ATTACK REACTION` (4), `MANOEUVRE` (2), `ATTACK EXERTION` (1), `ATTACK MANOEUVRE` (1),
  `FREE ATTACK` (1), `SPECIAL ACTION` (1). `SPECIAL ATTACK` and `SPECIAL MANOEUVRE` are legal and
  simply unused so far.
- **`SPECIAL` is a prefix, like `FREE`** — they share the slot, so `FREE SPECIAL ACTION` is not
  valid. They pull in opposite directions anyway: `FREE` costs nothing, `SPECIAL` always costs ether.
- **`| N` is the effect's ether cost** (D10), one space either side of the bar. It is a *per-effect*
  cost and **not** the card-level `Ether` column — Lark is a CHAMPION whose `Ether` is blank and
  whose `TRICK SHOT` costs 4. A `SPECIAL` without a cost is a data error and the validator says so;
  that is exactly what went missing from Lark in the D8 re-export (§6 item 1b).
- `validate_cast.py` exposes **`parse_effect_type()`**, which splits `'SPECIAL ACTION | 4'` into
  `('SPECIAL ACTION', 4)`. Nothing in the web app needs the two apart any more (D11) — it is there
  for the validator and for whoever needs the cost as a number later.
- The validator names *which part* is wrong — an unknown core, a prefix with no core, irregular
  whitespace, lower case, or one of the four pre-D8 spellings — rather than just rejecting the cell.
- **D8 dropped the redundant trailing `ACTION`.** An attack is an action unless it is a reaction, so
  `ATTACK ACTION` is simply `ATTACK`; likewise `MANOEUVRE`, `ATTACK MANOEUVRE` and `FREE ATTACK`.
  The word is kept where it carries meaning — `ACTION`, `FREE ACTION`, `SPECIAL ACTION` — and
  `REACTION` is untouched. The validator recognises the four pre-D8 spellings and names them as a
  stale export rather than just an unknown value. **Nothing renders the word `ACTION` itself**, so
  nothing needs to change here; the cell prints as given.
- **`formatRulesText()` still needs its curly-token rules** — but only for `Effect Details` and
  `Keywords`, which carry icon tokens like `{M3/Icons/Dice/SQUARE.png}` (46 cells). The existing
  rules already convert those to `<strong>[SQUARE]</strong>` **before** the catch-all, so this path
  works today. Don't remove it; just don't let it near the name/type columns, which need no parsing.
- Lowercase `manoeuvre` in `Effect Details` is **correct prose** (`When an enemy performs a
  *manoeuvre*...`) and must be left alone. Only the `Effect Type` labels are all-caps.
- **Lato is no longer a dependency of this section** (D11 — no effect styling). If the branding work
  wants it, **Chunk 7 owns it outright**; there is no longer an earlier chunk to coordinate with.

Two things this revision also cleared, recorded so nobody hunts for them: the `Cinderhulk` lowercase
casing artifact is **fixed** (now `ATTACK MANOEUVRE` under D8), and the trailing per-effect cost that used
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

**Corrected 2026-09-15 (Chunk 4).** This section originally listed **5** IDs — the three onboarding
champions and the two auto-summon minions. That was an undercount: `tts/TTS_Loader.lua` actually
hardcodes **32 distinct old-format IDs across 76 occurrences**. The missing 27 are the familiars and
special actions inside the `ONBOARDING_CASTS` table, which the original grep did not reach. All 32
are listed below; every one was resolved by name against the old `IN Cha-Tal`/`IN SP` pair (kept in
`.claude/worktrees/upgrade-plan/`) and matched to exactly one card in `M3_TTS_DB - Cast.csv`, with no
ambiguities. The five originally listed are unchanged — they agree exactly with the name-derived
mapping, which is what validates the method.

| Old | New | Card | Class | Where |
|---|---|---|---|---|
| `01RHA-01CMP-001` | `01RHA-01CHP-0001` | Flint Dross | Champion | onboarding cast |
| `01RHA-02FAM-002` | `01RHA-03FAM-0005` | Obduron | Familiar | onboarding cast |
| `01RHA-02FAM-003` | `01RHA-03FAM-0006` | Cinderhulk | Familiar | onboarding cast |
| `01RHA-02FAM-004` | `01RHA-03FAM-0007` | Saltpetre Pellobok | Familiar | onboarding cast |
| `01RHA-05SPA-001` | `01RHA-07SPA-0019` | Thermal Venting | Special Action | onboarding cast |
| `01RHA-05SPA-003` | `01RHA-07SPA-0021` | Smoke Cloud | Special Action | onboarding cast |
| `01RHA-05SPA-005` | `01RHA-07SPA-0022` | Obsidian Slumber | Special Action | onboarding cast |
| `01RHA-05SPA-006` | `01RHA-07SPA-0023` | Harden Crust | Special Action | onboarding cast |
| `01RHA-05SPA-038` | `01RHA-07SPA-0025` | Rupture Strike | Special Action | onboarding cast |
| `01RHA-05SPA-063` | `01RHA-07SPA-0030` | Tectonic Battery | Special Action | onboarding cast |
| `02IRO-01CMP-005` | `02IRO-01CHP-0034` | Ripple Elshara | Champion | onboarding cast |
| `02IRO-02FAM-006` | `02IRO-03FAM-0038` | Tumultuous Dropple | Familiar | onboarding cast |
| `02IRO-02FAM-007` | `02IRO-03FAM-0039` | Ponderous Dropple | Familiar | onboarding cast |
| `02IRO-02FAM-008` | `02IRO-03FAM-0040` | Puddling | Familiar | onboarding cast |
| `02IRO-03MIN-009` | `02IRO-04MIN-0048` | Driplet | Minion | auto-summon pool |
| `02IRO-05SPA-010` | `02IRO-07SPA-0055` | Tidal Surge | Special Action | onboarding cast |
| `02IRO-05SPA-011` | `02IRO-07SPA-0056` | Ameliorate | Special Action | onboarding cast |
| `02IRO-05SPA-012` | `02IRO-07SPA-0057` | Caught in the Eddies | Special Action | onboarding cast |
| `02IRO-05SPA-041` | `02IRO-07SPA-0058` | Permeate | Special Action | onboarding cast |
| `02IRO-05SPA-065` | `02IRO-07SPA-0062` | Undertow | Special Action | onboarding cast |
| `02IRO-05SPA-067` | `02IRO-07SPA-0064` | Aqueduct | Special Action | onboarding cast |
| `03VOI-01CMP-010` | `03VOI-01CHP-0068` | Lark | Champion | onboarding cast |
| `03VOI-02FAM-011` | `03VOI-03FAM-0072` | Huma'ra | Familiar | onboarding cast |
| `03VOI-02FAM-012` | `03VOI-03FAM-0073` | Lu'ann | Familiar | onboarding cast |
| `03VOI-02FAM-050` | `03VOI-03FAM-0078` | Stympharaq | Familiar | onboarding cast |
| `03VOI-05SPA-013` | `03VOI-07SPA-0086` | Dust Bath | Special Action | onboarding cast |
| `03VOI-05SPA-014` | `03VOI-07SPA-0087` | "Finish them!" | Special Action | onboarding cast |
| `03VOI-05SPA-016` | `03VOI-07SPA-0089` | Sand Blast | Special Action | onboarding cast |
| `03VOI-05SPA-017` | `03VOI-07SPA-0090` | "Let the talons fly!" | Special Action | onboarding cast |
| `03VOI-05SPA-018` | `03VOI-07SPA-0091` | Snare | Special Action | onboarding cast |
| `03VOI-05SPA-048` | `03VOI-07SPA-0095` | Flee | Special Action | onboarding cast |
| `05AHE-03MIN-022` | `05AHE-04MIN-0148` | Huskling | Minion | auto-summon pool |

The `CMP/FAM/MIN/TAL` segment map also appears in `Floating_Health_Tracker.lua` **and** is duplicated
inside `Model_ID_Injector.lua` (which embeds the tracker source). Per **D2** both copies are
**deleted**, not updated — see §3.2. These IDs in `TTS_Loader.lua` are genuine identifiers being
looked up, not parsed for meaning, so they do just need the new values.

**`Model_ID_Injector.lua` still declares its own `CHARACTERS_ZONE_GUID`** (line 17, same `83f62b`).
Chunk 4 did not touch it — that is Chunk 5's file. It points at the same physical zone, so it keeps
working once the merged Cast deck sits there.

---

## 4. Chunks

Dependency order. **0 -> 1 -> 2** is a hard chain (each needs the previous). **4 -> 5** is a second
chain that needs 1. **6 -> 7** (branding) touches only `CastRecruiter.html` styling and is
independent — run it any time, including first if you'd rather see progress on the look early.

**Chunk 3 was withdrawn (D11)** and its number is kept as a tombstone so 4-7 don't shift under the
handover notes that already cite them.

```
0 ── 1 ─┬─ 2               (data pipeline -> backend)
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
  the §3.4 effect-type grammar (D9); `Effect Name N` and `Effect Type N` are populated
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

**Effect types are checked against the D9 grammar, not a closed list**, so vocabulary tweaks no
longer require a validator change. **Passes clean, exit 0.** Both data problems it found are fixed:
the 4 misaligned effect pairs (§6 item 1a) and Lark's missing `| 4` ether cost (§6 item 1b).

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

**Done 2026-09-15.** The script is a rewrite, not a patch: `CompileError` + hard bails replace the
old `print`-a-warning-and-carry-on style, since every fault it can hit would otherwise write a
silently shifted deck.

- **200 ID-keyed entries** in `webapp/CardImages.gs`, one card per line (215 lines, down from 1070).
  `node` confirms `getCardImageMappings()` parses and returns 200 cards. All 200 `url`/`idx` values
  cross-check against the deck's own `CustomDeck` sheets independently of the compiler; no
  `{verifycache}` prefix survives.
- **200 `Nickname` / `GMNotes` / `Description`** injected, each equal to the CSV's `Name` / `ID` /
  `Class`. The class census on the cards matches §2.3 exactly, and the 4 MINION-class companions of
  §3.2 (Tocarin, Calazi, Opolkan, Pashan) carry `MINION` — the health bug Chunk 5 inherits is
  already defused in the data. **No card fell back to a synthetic ID.**
- **`validate_cast.py` still passes clean (exit 0)** against the injected deck.
- **The pre-D7 header bug is now a hard failure.** The old script read `"Name (str)"` / `"ID (str)"`
  literally and injected empty strings without erroring; `REQUIRED_COLUMNS` refuses instead, naming
  the columns it found.
- **Teeth proven on copies**, each exit 1 with the spreadsheet row named: pre-D7 headers, a 199-card
  deck against 200 rows, a duplicate ID, a blank `Class`, a `DeckIDs` list reordered against
  `ContainedObjects`, and a missing `CustomDeck` sheet.
- **The glob excludes the superseded exports by name, not by mtime.** `MonuMentuM Characters/Specials
  08-06-2026.json` still match `MonuMentuM *.json` and are still on disk; ordering on the
  `DD-MM-YYYY` in the filename (with the qualifier files filtered out) means a fresh clone, which
  resets every mtime, cannot compile the wrong, differently-shaped export.
- **The deck is written back minified and ASCII-escaped, matching Dextrous's own export shape**, so
  an injection is a one-line diff and so is the next re-export. Writing `indent=2` would have made
  every round trip fight over the whole file.

**Re-run the compiler after every Dextrous re-export — the art URLs are not stable.** The
2026-09-15 re-export (corrected card back, one typo re-rendered) kept all 10 face/back storage paths
identical but rotated **all 10 Firebase `token=` values**. A re-render therefore invalidates every
URL already in `CardImages.gs` while leaving the filenames looking unchanged, so a stale map points
at dead links and the art simply fails to load. Regenerating also re-injects the deck, which a fresh
export always arrives without.

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
- **Compose the `effect` string — this is the contract now, not a temporary bridge (D11).** The print
  card renders `card.effect` through `formatRulesText()` and nothing else, so everything that must
  reach paper has to be in that one string. Under the old single `Effect` column the name and type
  were already inside it; passing only `Effect Details 1` would **silently drop the effect name, type,
  cost, and the whole second effect on the 7 cards that have one.** Build it as plain text:

  ```
  SMOLDER | FREE ACTION
  All allies within **AURA(5)** become "Molten"...
  VITRIOLIC QUENCH | ABILITY
  ...
  ```

  Name and type joined by ` | `, the cost already inside the type cell (D10), details on the next
  line, effects separated by a newline. Omit the header line where a card has details but no
  name/type (113 of 200 cards). Note `formatRulesText()` collapses `\n+` to a single `<br>`, so a
  blank line between effects won't render as a gap — acceptable under D11's "minimal styling", not a
  bug to chase.
- Also pass through `effect1Name`, `effect1Type`, `effect1Details`, the `* 2` equivalents,
  `keywords`, `flavourText` and `artwork` as structured fields. Nothing consumes them today; they
  cost nothing and save a backend round trip if anything ever does.
- Keep the closing `JSON.parse(JSON.stringify(db))` sanitiser.
- **Do not** add a second card-fetching function in another `.gs` file (see `CLAUDE.md` — flat global
  namespace; this has bitten the project before).

**Test:** `clasp push` from `webapp/`, open the web app. For each of the 6 dominions: champion list
populates, basics list populates, talismans appear, signature actions show under the right champion,
loyal companions show under the right champion. Confirm the new cards from §2.5 are present. Confirm
card art still loads.

- **Verify the print card still works** (D11): open print preview with a full cast and confirm the
  effect text appears, icon tokens render as `[SQUARE]` rather than raw `{M3/Icons/…}`, no stray `{`,
  `}` or `*` survive, and the 3x3 A4 page grid still breaks correctly. Keep it plain — improving the
  print styling is explicitly **not** in scope.
- Confirm the `cost > 0` recruitability guard still behaves: `Driplet` and `Huskling` have **blank**
  Ether, which `parseInt('') || 0` keeps out of the recruitable basics list. Confirm rather than
  change.

**Done when:** all 6 dominions build a legal cast end to end, the 6 companion/signature links from
§3.1 resolve, and print preview still produces readable cards.

**Done 2026-09-15 — confirmed working in the browser by Harvey.** `getCardDatabase()` is a rewrite, not a patch.
`CHAR_SHEET_NAME`/`SP_SHEET_NAME` collapse to a single `CAST_SHEET_NAME` (now `"IN Cast"` — the tab
was renamed twice while this chunk was in flight); `MATCH_SHEET_NAME` is untouched. Verified by running the real function over the real 200-row CSV in a Node harness with
`SpreadsheetApp` stubbed — 29 assertions, all passing, **zero warnings**:

- **200 cards** — 12 champions, 86 units (68 Familiar + 6 Minion + 12 Talisman), 102 specials, 6
  dominions. Class census matches §2.3 exactly, in **Title Case** (`SPECIAL ACTION` -> `Special
  Action`) so the frontend's `class === 'Minion'` / `'Talisman'` comparisons keep working unchanged.
- **All 24 champion links resolve** — 12 loyal companions, 12 signature actions, every
  `tiedChampionId` pointing at a real champion's **card ID**. `id` is the card ID now, not
  `champ_<index>`, and `uniqueId` carries the same value so the roster import/export paths are
  unchanged.
- **`normaliseName()` is a direct port of `normalise_name()`** (`dextrous/validate_cast.py`), not a
  re-reading of §3.1. Checked against the Python original over **215 inputs — zero drift**, the
  `ø đ ł ß œ` cases included. It is load-bearing: a naive exact match fails on exactly the 5 §3.1
  cards (Pelazhiqi, Ryuztli, Kibantli, Opolkan, Egunghi). Matching is scoped within the dominion.
- **All 200 cards resolve art** from `getCardImageMappings().cards[cardId]`, every entry carrying a
  well-formed `url`/`cols`/`rows`/`idx` and no `{verifycache}` prefix. This is what restores card art
  in the browser view.
- **The composed `effect` string** is the contract (D11): 84 cards emit a `NAME | TYPE` header, the
  113 with details but no name/type **omit the header line** rather than emitting a stray ` | `, and
  all 7 second effects are present.
- **`Driplet` and `Huskling` still cost 0**, so the frontend's `cost > 0` guard keeps them out of the
  recruitable basics list — confirmed, not changed.
- **Teeth proven on in-memory copies**, each throwing and naming the sheet row: a renamed/missing
  required column, a duplicate ID, a blank ID, a blank `Class`, an unrecognised `Class`, a
  header-only tab, and a missing `Cast` tab. Trailing blank rows are skipped rather than fatal.
- **Soft degradation preserved**: an unresolvable `Role Details` warns and leaves `tiedChampionId`
  null rather than throwing, and a missing `CardImages.gs` still builds all 200 cards with
  `image: null`.
- **Print card renders clean.** All 200 composed `effect` strings pushed through the real
  `formatRulesText()` + `escapeHtml()` lifted out of `CastRecruiter.html`: no `{`, `}`, `*` or raw
  `{M3/Icons/` survives, and the 37 icon-token cards render as `[SQUARE]` and friends.
- `validate_cast.py` still passes clean (exit 0).

**Getting there took four data faults, none of them in this chunk's code.** In order: 7 unbalanced
asterisks in `Effect Details`; the cast tab renamed twice (`IN CAST` -> `Cast` -> `IN Cast`); the
sheet feeding Dextrous holding a stale row order, which misaligned every injected name against its
art; and the repo's CSV snapshot drifting from the live sheet on two Xalakith rows. The last two are
invisible to every automated check — see `dextrous/make_contact_sheet.py`.

**Two things this chunk surfaced, neither a code bug. The second is now fixed:**

1. **`role` now carries `COMPANION`/`SIGNATURE`, not the old prose** (`"Flint Dross's Loyal
   Companion"`). The print card's subheader is `[dominion, role].join(" • ")`
   (`CastRecruiter.html:1417`), so it reads **"Rhavlika • COMPANION"**. The prose is still available
   — the champion's name is passed through as the new `roleDetails` field — but nothing renders it.
2. ~~**7 cards have unbalanced asterisks in `Effect Details 1`**~~ — **fixed by Harvey in the sheet
   on 2026-09-15 and re-exported.** `***MANOEUVRE` -> `**MANOEUVRE` on Lu'ann, Dart, Flee and
   "Charge the flanks!"; `*ADVANTAGE**` -> `**ADVANTAGE**` on Breach; `*emergence"` -> `*emergence*`
   on Displacement; `**SLOWED*` -> `**SLOWED**` on Veros' Breath. The CSV diff was exactly those 7
   rows and nothing else, and the print card now renders with **zero** stray asterisks. **The card
   *art* still carries the old rendering** until Dextrous re-renders and the deck is re-exported —
   the fix is in the sheet, not in the images.

---

### Chunk 3 — ~~Frontend: new effect model and new fields~~ — WITHDRAWN (D11)

**Not being done.** The web app renders card *images*, not effect text, so there is no effect model
to build in the frontend.

- The **browser view** paints the sprite-sheet card face via `getCardStyle()`
  (`webapp/CastRecruiter.html:1266`). It never rendered effect text.
- **Print preview** is the only place effect text appears, through
  `formatRulesText(card.effect)` (line 1466). It is meant to be a plain, printer-friendly text card
  for home printing and **stays that way** — Harvey's call, 2026-09-14. Improving its styling is
  explicitly out of scope for this plan; it may get attention later.

What this withdrawal dropped: Lato 300/600 loading, `effect-name`/`effect-type` spans, two-effect
blocks, and surfacing `Keywords` and `Flavour`.

What survived, and where it went — **all of it into Chunk 2**:

- **Compose the legacy `effect` string** so the print card keeps showing the name, type, cost and
  both effects. This is the one genuine regression risk in the whole withdrawal: pass only
  `Effect Details 1` and the print card silently loses information it used to print.
- **Verify print preview still works** — icon tokens, no stray braces, 3x3 A4 grid intact.
- **Confirm the `cost > 0` recruitability guard** still keeps `Driplet` and `Huskling` out of the
  basics list.

`formatRulesText()` stays exactly as it is: it escapes first, converts `**bold**`, `*italic*` and
`{M3/Icons/…}` tokens, then strips leftover braces. Don't remove its curly-token rules — 46 cells
still carry icon tokens, and they reach paper through this function.

The frontend's Title-Case class comparisons (`u.class === 'Familiar'` and friends, at lines 965,
1059, 1134, 1635, 1651) need **no change**: Chunk 2 normalises `Class` to Title Case at the parse
boundary precisely so the 1734-line frontend stays untouched.

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
- Update the 32 hardcoded IDs per the table in §3.7 (76 occurrences — not 5; see the correction there).
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
2. ~~**Fix the `Cinderhulk` effect-type casing**~~ — **done**, arrived with the D7 re-export; now
   `ATTACK MANOEUVRE` under D8.
1a. ~~**Fill in 4 missing effect name/type cells**~~ — **done 2026-09-14**. The Chunk 0 validator
   flagged 4 rows in the Veritian block with a name but no type, or the reverse; the cause was
   **misaligned effect rows**, not 4 isolated typos, so the fix moved cells across the whole effect
   block. Re-exported the same evening together with the D8 vocabulary change. `Effect Name N` and
   `Effect Type N` are now paired on all 200 rows (84 in slot 1, 7 in slot 2) and the validator
   passes clean. The roster itself is unchanged — same 200 IDs and names, verified against the
   previously committed CSV.

1b. ~~**Restore `Lark`'s ether cost**~~ — **done 2026-09-14**. `03VOI-01CHP-0068` (sheet row 69),
   `TRICK SHOT`, now reads `SPECIAL ACTION | 4`. One cell changed; the validator passes clean.

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
