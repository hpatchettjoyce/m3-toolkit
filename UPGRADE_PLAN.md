# M3 Toolkit — Upgrade Plan (single-sheet cast DB, new cards, branding)

**Created:** 2026-09-14 · **Revised:** 2026-09-14 (decisions D1–D6 folded in, see §1.1)
**Status:** Chunks 0–2 verified in the browser; 4 and 5 confirmed in TTS; **6 and 7 (branding) seen
in the browser 2026-09-16 — Harvey: "does look better but it can be improved"**, and the six
improvements he raised are specced as **Chunk 8, which is next** (Chunk 3 is withdrawn, D11). The
one known failure is the favicon: `setFaviconUrl` errored "not supported", now Chunk 8 item 7. The
CSV was re-exported 2026-09-16 with Lark's ether cost moved into the effect text (**D12**, which
supersedes D10); the validator passes on it. The validator passes clean, the compiler
emits an ID-keyed `CardImages.gs` with all 200 cards, and `main.gs` serves all 200 from the single
`IN Cast` tab with art looked up by card ID.
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
| D10 | ~~**An effect may carry an ether cost, written `\| N` at the end of `Effect Type N`** — `SPECIAL ACTION \| 4`. **A `SPECIAL` always has one**, and the validator enforces that.~~ *(**Superseded by D12, 2026-09-16.** The cost moved into the effect text as a `**ETHER(N)**:` tag and the `SPECIAL` effect-type prefix is retired. The per-effect vs card-level distinction D10 drew still holds — Lark is still a CHAMPION with a blank `Ether` whose `TRICK SHOT` costs 4 — only the place the cost is written has changed.)* | §3.4, Chunk 0, Chunk 2, Chunk 8 |
| D9 | **Effect types are validated as a grammar, not a list.** `ABILITY`, or `[FREE\|SPECIAL] ACTION/ATTACK/MANOEUVRE/ATTACK MANOEUVRE [REACTION/EXERTION]`, either optionally followed by an ether cost (D10) — brackets optional, slashes either/or. A closed list broke on every vocabulary tweak; the grammar accepts new legal combinations without a code change. *(**D12 narrows this:** the trailing ether cost and the `SPECIAL` prefix are both retired, so the grammar loses two branches. The grammar-not-a-list principle is unaffected.)* | §3.4, Chunk 0, Chunk 2, Chunk 8 |
| D8 | **Effect-type vocabulary trimmed on 2026-09-14**: the redundant trailing `ACTION` is dropped wherever the type already implies one — `ATTACK ACTION` -> `ATTACK`, `MANOEUVRE ACTION` -> `MANOEUVRE`, `ATTACK MANOEUVRE ACTION` -> `ATTACK MANOEUVRE`, `FREE ATTACK ACTION` -> `FREE ATTACK`. An attack *is* an action unless it is a reaction. `ACTION`, `FREE ACTION`, `SPECIAL ACTION` and `REACTION` keep the word. Same re-export fixed the misaligned effect rows. | §2.2, §3.4, Chunk 0, Chunk 2 |
| D7 | **Effect columns were re-split on 2026-09-14**: `Effect Name N` / `Effect Type N` / `Effect Details N`, all clean, no Dextrous markup; `Flavour Text` renamed `Flavour`. The roster is unchanged. Anything referencing `Effect 1 - Name` or `{EffectName:…}` is a stale export. | §2.2, §3.4, Chunk 0, Chunk 2 |
| D12 | **A per-effect ether cost is written in the effect *details* as a leading `**ETHER(N)**:` tag, and the `SPECIAL` effect-type prefix is retired** (Harvey, 2026-09-16). Lark's `TRICK SHOT` went from type `SPECIAL ACTION \| 4` to type `FREE ACTION` with `**ETHER(4)**:` at the head of its body line. **`SPECIAL ACTION` remains a card *Class*** (102 cards) — only the effect-type prefix is gone. Supersedes D10. **The cost:** nothing now marks an effect as one that *should* cost ether, so a dropped tag is silent where D10's rule made it a hard error. | §3.4, Chunk 8 |

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

**Deploying a change to either script means re-pasting `Model_ID_Injector.lua` into the injector
token in TTS — not just re-importing the deck.** This cost a full test round on 2026-09-15: the deck
was re-imported and the injection re-run, but the *old* injector was still on the token, so minions
still read 6. A stale injector (a) blanks `Description`, so no class is stamped, and (b) carries its
own embedded copy of the health tracker and writes it onto every model, re-installing the old
ID-parsing logic on all 200. **`Floating_Health_Tracker.lua` is never pasted by hand** — the injector
is its delivery mechanism, which is why the embedded copy must stay byte-identical to the standalone
file. Quick tell for which version is loaded: the string `Class check` exists only in the current
injector, so no `Class check` line in the console means the token still has the old script.

**The long-standing "standees don't face the player who drew them" defect resolved itself in the same
pass (Harvey, 2026-09-15): *"The orientation was working as well. Not sure why it wasn't before."***
No rotation code was changed. `targetModelRot` (`TTS_Loader.lua:353`) still reads
`Red -> {0,270,0}`, `Blue -> {0,90,0}` — the values two earlier commits (`bb3670a`, `d5971ce`) had
already converged on. The likeliest explanation is that the models themselves carried stale state
until they were re-injected from a correctly-updated injector. **Had a third speculative Y-flip been
committed, it would have broken a setting that was already correct** — the reason it was left alone
is worth remembering the next time a 3D defect can't be reproduced offline.

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

**Prerequisite: SATISFIED (2026-09-15).** `assets/branding/M3 Branding Guide.pdf` is in the repo and
committed. **The palette is already extracted — start from `assets/branding/palette-extracted.md`,
not from the PDF.** All 18 swatches, RGB-cross-checked 18/18, plus the embedded font list for
Chunk 7. Re-derive with `python3 dextrous/extract_brand_palette.py`.

Two things that file settles before you start: the off-black ground this chunk asks for is
**`#041212` (OFF-BLACK)**, with `#374141` / `#999F9F` as panel and border steps and `#F8F3E6`
(OFF-WHITE) as body text; and **the guide specifies only four chromatic hues against six dominions**,
so the `FACTION_COLORS` re-map below has no answer in the guide and needs Harvey. Note also that no
PDF tooling is installed here, so the PDF cannot be read visually without
`sudo apt-get install -y poppler-utils`.

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

**DONE 2026-09-15** — in three commits, deliberately separate:

1. `c5240d3` tokenised all 62 hardcoded colours with no visual change. The tokens split into
   **screen chrome** and **`--ink-*`** (the printed sheet). That split is the load-bearing part:
   the `.print-card*` rules live *outside* `@media print` because they also render the on-screen
   print overlay, so scoping the dark theme to the `@media print` block alone would have leaked
   off-black onto the printed cards. A separate ink family makes that structurally impossible.
2. `dd73bfa` applied the off-black ground. Two things a token swap could not express: form controls
   needed an explicit `color` (their background is now near-black and an undeclared `select` keeps
   the UA's black text), and `--field-border-colour` had to split out of `--border-colour` — on
   white a faint border serves both dividers and inputs, but on dark the field and the ground are
   the same colour so the outline is the only cue a control is there.
3. `f5dfe64` re-mapped `FACTION_COLORS`. See below.

**`dextrous/check_theme_contrast.py`** is new and re-runnable: it reads the tokens and both dominion
maps out of `CastRecruiter.html` and asserts 32 colour pairs plus all six dominions on paper, each
labelled with the rule that renders it. Run it after any colour edit.

Two findings worth keeping:

- **`--success-colour` and `--warning-colour` are not only fills.** They are also the ether and
  specials tracker text (`updateTrackers()`), so each had to clear 4.5:1 both as a fill behind
  off-black text and as text on the panel. That constraint is what picked the values.
- **`FACTION_COLORS` is referenced in exactly one place, `generatePrintCard`.** So the dominion
  colours only ever appear as ink on white card stock in this tool — they never touch the dark UI.

---

### Chunk 7 — Branding pass 2: logos and typography

**Prerequisite: SATISFIED (2026-09-15).** Both `assets/branding/Horizontal_Filled_Light.svg` and
`.png` are in the repo. The SVG — mark and wordmark as one image, a single `fill: #eea145` on one CSS class `.cls-1`, so it
recolours trivially once inlined. **Inline it rather than hosting it:** GAS serves one HTML file
through `HtmlService` with no static asset hosting, and switching `.cls-1` to `currentColor` lets
one file serve both the dark chrome and the light print styles.

**The PNG landed too** (6208x1331), and it is the raster master for anything that cannot take
vector — TTS takes textures only. It is *not* the right favicon source: see the DONE block below.
Note the guide's own gold is `#eea145` while the palette's GOLD STONE is `#E4A557`; the SVG is the
supplied asset, so it wins, but do not "correct" one to the other without asking.

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

**DONE 2026-09-15** — three commits, `8214fee`, `27b2c43`, `50f0284`.

**The typography question is answered, and the answer is narrow.** The guide's PG.07 is titled
"MONUMENTUM - Logo Typography", labels its one specimen "LOGO TYPEFACE", and shows **Cinzel
Medium** — nothing else. Avenir, ArbanePixel, Alda and Times are embedded in the PDF because they
set the *presentation deck*, not the brand; the font resource map proves it, they are the faces
drawing the guide's own body copy and page furniture. So there is no brand body face to apply, and
`8214fee` uses Cinzel for display type only (h1, h2) behind two new tokens, `--font-display` and
`--font-body`. Cinzel is OFL and on Google Fonts, so it links rather than needing a licence.
Re-derive any of this with `python3 dextrous/extract_brand_palette.py` — the same zlib trick reads
text, not just swatches.

`27b2c43` inlines the horizontal lockup as an **SVG sprite**: one `<symbol>` at the end of the body,
one `<use>` in the header. The plan asked whether the bulk was acceptable — it is 44 lines and
16.7KB, and worth it: Apps Script has no static asset hosting, so the alternative was a 148KB PNG
as a ~198KB base64 blob that could not recolour. The asset's `.cls-1 { fill: #eea145 }` becomes
`currentColor`. The logo carries the wordmark, so the `h1` is now just "Cast Recruiter".

Three findings worth keeping:

- **`--logo-colour` is its own token, not `--accent-colour`.** The supplied SVG's gold is `#eea145`;
  the palette page's GOLD STONE is `#E4A557`. Keeping a separate token records the divergence in one
  place rather than silently resolving it. The contrast checker now asserts it (33 pairs).
- **The favicon cannot be set from the HTML.** Apps Script serves the page in an iframe under a
  Google-owned top-level document, so a `<link rel="icon">` never reaches the browser tab.
  `HtmlOutput.setFaviconUrl()` is the route, it *fetches a URL*, and a `data:` URI will not do — so
  this is the one branding item that needs a hosted file. `FAVICON_URL` in `main.gs` is guarded and
  empty, so behaviour is unchanged until a URL is pasted in.
- **The horizontal PNG is the wrong favicon source.** At 4.7:1 it is a sliver at 16px. The favicon
  wants the **square logomark** (guide PG.02), which has not been supplied. There is no raster
  tooling on this machine — no PIL, ImageMagick or `rsvg-convert` — so it cannot be cropped here.

**Deliberately not done:** no logo on the print card. The lockup's gold is only 2.14:1 on white,
the cards butt with no gap so a logo would crowd the cut line, and the chunk's low-ink goal argues
against it. Worth revisiting only if Harvey asks.

**Outstanding, needs Harvey:** a square logomark PNG hosted at a public URL, pasted into
`FAVICON_URL`. Everything else in the chunk is code-complete.

---

### Chunk 8 — Layout density and readability

**Prerequisite: SATISFIED.** Nothing to supply. Every measurement below was taken from the file as
it stands after Chunk 7, and the effect text this chunk needs is **already in the payload** —
`baseCard()` in `main.gs:430` ships `effect` (composed), `effect1Name/Type/Details`,
`effect2Name/Type/Details`, `keywords` and `flavourText` for every card, and the frontend already
renders it for paper through `formatRulesText()` (`CastRecruiter.html:1524`). So no backend work and
no new columns.

**Goal:** fit a cast on one or two screens instead of five, and make a card's effects readable
without squinting at the art.

**Raised by Harvey 2026-09-16** after the first browser pass of Chunks 6–7: *"The Webapp does look
better but it can be improved."*

#### The tension to settle first (items 1 and 3 pull against each other)

Measured, not guessed. `.container` is `max-width: 1200px` with `30px` padding (`:84`), so content is
**1140px**. `.card-grid` is `repeat(auto-fill, minmax(240px, 1fr))` with a `20px` gap (`:105`), which
yields **4 columns of 270px** today, with `.visual-card` capping the art at `260px` (`:126`).

Asking for 5 columns *inside the same 1200px container* gives `(1140 − 4×20) / 5 =` **212px** cards —
an 18% shrink, when item 3 says the cards are already too small. The two asks are only compatible if
the container gets wider on large screens:

| Container | Content | 5 cols @ 20px gap | vs. today's 260px |
|---|---|---|---|
| 1200px (today) | 1140px | 212px | −18% |
| 1400px | 1340px | 252px | −3% |
| **1600px** | 1540px | **292px** | **+12%** |
| 1760px | 1700px | 324px | +25% |

**Recommendation: widen to 1600px, drop the `260px` cap on `.visual-card`, and make the tracker
widget a laid-out right rail rather than a fixed overlay** (which item 6 wants anyway). That gives 5
across at ~292px — bigger than today's 4 across at 260px — and it is the only version of this that
survives a 1680px screen.

The reason the rail matters: `.floating-status-widget` is `position: fixed`, so it takes no layout
space and nothing stops a wider container sliding underneath it. Reserving space with a centred
`max-width` is possible but expensive, because **a centred box gives back only half of whatever you
subtract** — clearing a ~190px rail needs `min(1600px, 100vw - 380px)`, not `- 190px`. At a 1920px
viewport that still yields 280px cards, but at 1680px it drops to 232px, i.e. *smaller* than today.
So the cheap fix works only on very wide screens; the rail is the real answer.

#### 1. Five across on the desktop, one on the phone

Replace the `auto-fill` track with explicit counts, so the column count is a decision rather than a
side effect of the minimum width:

| Width | Columns |
|---|---|
| ≥ 1400px | 5 |
| 1100–1400px | 4 |
| 900–1100px | 3 |
| 600–900px | 2 |
| < 600px | 1 |

Existing breakpoints are at `:372` (1100), `:393` (900) and `:399` (600) — a 1400px one is new.
Below 600px the grid is already `repeat(1, 1fr)`, so the phone case only needs its `max-width: 200px`
art cap raised, since one card per row can afford to be large.

#### 2. Reading the effects — DECIDED: option 1 only, desktop only

The art is a **sprite-sheet slice**, not a per-card image: `getCardStyle()` (`:1374`) sets
`background-size: ${cols*100}% ${rows*100}%` and a percentage `background-position`. That matters
twice over — there is no bigger version of the art to swap in, but the same trick zooms to any
factor by scaling both numbers. These are the five, most-recommended first:

1. **Caption under the tile (recommended, and what item 3 asks for).** The tile becomes a
   contact-sheet `figure`: art flush on top, a text box beneath carrying
   `formatRulesText(card.effect)`. Live HTML text at whatever size we choose, so the art never has
   to be legible at all. Reuses the existing data and the existing formatter; nothing new to build
   or maintain. Costs vertical space per tile — which item 5 is separately clawing back.
2. **Hover / focus zoom (recommended as the companion to 1).** On hover or keyboard focus, a fixed
   panel shows the same slice at ~3× with the effects as text beside it. Cheap, because the sprite
   maths already supports it: multiply both `background-size` percentages by the zoom factor. Needs
   a focus trigger as well as hover, and does nothing on touch — acceptable, since Harvey scoped
   this to desktop.
3. **Click-to-open detail modal.** Mirrors the existing import modal (`#import-modal`), showing the
   art large plus the *split* fields as labelled rows — name, type, details, per effect — rather
   than the composed blob. Best readability of the five and the only one that can show flavour text
   and keywords too; costs a click and a dismiss per card.
4. **A density toggle: "art" vs "text".** One control swaps the grid for a compact table — name,
   cost, class, effects — for scanning while building, then back to art for the visual check. Helps
   the scrolling complaint more than any other option here, because it removes the art entirely.
   Two layouts to keep working instead of one.
5. **Progressive disclosure in the caption.** The caption shows only effect *names and types*, one
   line each, and expands to full details on click. Keeps the 5-across grid short while the full
   text stays one interaction away. Needs an expanded-state design that doesn't reflow the whole
   grid — the fiddliest of the five.

**DECIDED 2026-09-16 — build option 1 alone.** Harvey, on the zoom that was recommended alongside
it: *"I'm concern a hover/focus zoom will be annoying when traveling around the app and would be too
different for phones."* Both are fair: a hover panel firing on every tile the pointer crosses while
scrolling a 5-wide grid is noise, and it would have no touch equivalent, so the phone and the
desktop would work differently. **Options 2–5 are rejected, not deferred** — don't re-propose them
without new reason.

**And the caption is desktop-only.** Harvey: *"as we'll render the sprite at a whole card per screen
for a phone I'm hoping we won't need the additional effect 'drawer' so we can hide it in that
format."* Below 600px the grid is already one card per row, so the art itself is rendered large
enough to read the baked-in effects — the caption would be duplicating what the card already says,
at the cost of the vertical space this whole chunk is trying to win back. So: caption visible from
600px up, hidden below it.

**Do not hide the whole caption box on the phone, though — only the ability text.** Harvey's second
answer puts the quantity badge *inside* that same box (see item 3), and quantity has to be settable
on a phone. The box therefore needs two parts with different breakpoint behaviour: a control row
(badge; always present, where the card takes a quantity) and an ability block (text; ≥600px only).
Getting this wrong makes Basic Familiars unbuildable on a phone, which no test of the desktop layout
would catch.

*Sixth possibility, noted, not counted, and now moot:* `generatePrintCard()` (`:1543`) already
composes a complete card face out of live text, but it is ink-styled (light on white, `--ink-*`) and
would need a chrome-themed twin, which **CLAUDE.md warns against**. Option 1 gets the same
readability without a second renderer.

#### 3. Kill the gutter around the art

The "gutter" is `border: 3px solid transparent` on `.visual-card` (`:131`), reserved for the
selected state. Because the background's positioning area is the padding box, the art stops short of
that border and the 3px frame shows `--card-back-colour` on all four sides.

- Drop the transparent border and draw selection with `box-shadow: 0 0 0 3px var(--accent-colour)`
  instead. A box-shadow takes no layout space, so selecting a card also stops nudging the grid.
  (`--accent-colour` on `--panel-bg` is already asserted at 3:1 by the contrast checker.)
- Restructure the tile to match `dextrous/contact_sheet.html:13-20`, which is the look Harvey
  likes: `figure` with `border`, `border-radius: 8px`, art flush at `aspect-ratio: 5/7` — the same
  1:1.4 the app already uses — and a `figcaption` below it. The caption box is where item 2's
  option 1 puts the ability text.
- **DECIDED 2026-09-16: the quantity badge moves into that caption box**, out of its current
  floating position at `top/right: -8px`. Harvey: *"Add the quantity badge to section below the card
  where we're putting the legible ability text."* This is the change that makes the flush look
  possible — with nothing overhanging the art any more, the tile **can** take `overflow: hidden`
  exactly as `contact_sheet.html` does, and the clipping trap stops existing rather than being
  worked around.
- Consequences worth designing for, not discovering: the badge becomes a normal in-flow control, so
  it needs a visible label (a bare number floating over art reads as a badge; sitting in a text box
  it does not — `Qty` or a `×` prefix), it must keep `stopPropagation()` on click so changing a
  quantity doesn't also toggle selection (`:1105`), and it must stay visible on the phone even
  though the ability text beside it is hidden — see item 2.
- The caption's own layout therefore has three states: art-only (champions, talismans — nothing to
  show but the effect text), text-only, and text-plus-badge (Basic Familiars and Minions).

#### 4. Montserrat as the general font

`--font-body` (`:66`) becomes Montserrat with the current stack as fallback. Two points:

- **This is Harvey's call, not the guide's.** The guide specifies *no* body face — Cinzel is the
  logo typeface only (PG.07), which Chunk 7 settled. Montserrat is a choice, and a sane one: it is
  OFL, on Google Fonts, and a geometric sans that sits well under an inscriptional Roman serif.
- It joins the **existing** Google Fonts request at `:10` as a second family in the same URL, not a
  second `<link>`. **`--font-display` stays Cinzel and the print card stays Arial** — the metric rule
  from Chunk 7 is unchanged and is in CLAUDE.md.

#### 5. Fold Loyal Companions and Signature Actions into the sections they belong to

Today `#recruitment-section` stacks *Loyal Companions* above *Basic Familiars & Minions* above
*Talismans*, each with its own `h3` and its own full-width grid (`:770-780`), and `#specials-section`
stacks *Signature Actions* above *Special Actions* (`:783-793`). Each `h3` plus its grid's
`margin-bottom: 30px` is pure vertical cost when the group holds one or two cards.

Target: the loyal group occupies the **first cells of the familiars row**, boxed and labelled, with
the basic familiars flowing on after it in the same row — and the same for signature actions inside
special actions.

- **Preferred mechanism: one grid, with the boxed group as a grid item spanning `n` columns and
  `grid-template-columns: subgrid`.** Subgrid is what keeps the boxed cards exactly the same width
  as the unboxed ones; without it the box's border and padding make its cards narrower and the row
  looks broken. Baseline-supported in current Chrome, Firefox and Safari.
- The box itself: `fieldset` + `legend` is the honest markup for "a box with a legend", and gives
  the grouping to screen readers for free.
- **Fallback if subgrid proves awkward:** a flex row of two items — the fieldset at its natural
  width, the familiars grid at `flex: 1`. Simpler, but card widths differ between the two halves.
  Settle this at build time against the real card counts; don't design for it in advance.

#### 6. Move Print and Export up beside the trackers

`#btn-print` and `#btn-export` sit in the last section (`:802-806`), below everything. They move
under the Ether and Specials readouts in `.floating-status-widget` (`:183`).

- `#export-output`, the JSON textarea, is the loose end: it cannot follow the buttons into a
  150px-wide widget. **Export should open a modal instead**, mirroring the import modal that already
  exists — symmetric with "Import Cast JSON", and it removes the last full-width section entirely.
- Below 1100px the widget already reflows from a fixed corner box to a sticky horizontal row
  (`:373`); the buttons have to survive that change, so they need a row layout there too.
- Moving the buttons into a `position: fixed` element makes them permanently reachable, which is the
  point, but it also makes the widget the widest thing on the right — see the collision gotcha.

#### 7. The favicon, which failed

Harvey, 2026-09-16: *"I tried to add the favicon but I get an error it is not supported."*

**Largely diagnosed already.** He had pasted a Drive `thumbnail?id=…&sz=w256` URL into
`FAVICON_URL`, which is a **redirect with no image extension** — the URL shape most likely to be
refused. So the fault is almost certainly the URL, not the call.

**Already fixed: the failure can no longer kill the app.** Anything thrown inside `doGet()` escapes
it and the page never renders at all, so a rejected favicon URL was taking down the whole web app
rather than just dropping the icon. `setFaviconUrl` is now wrapped in a try/catch that warns to the
execution log (`main.gs:48-54`). Harvey's URL is left in place, so a re-push shows whether it works
with the crash risk removed.

**Next, if the icon still doesn't appear:** use a direct URL ending in `.png`. This repo is public
on GitHub, so committing a square logomark to `assets/branding/` gives one for free:

```
https://raw.githubusercontent.com/hpatchettjoyce/m3-toolkit/main/assets/branding/favicon.png
```

He appears to have the square asset already — the Drive id in `FAVICON_URL` points at something he
uploaded for this — so this may be a copy into the repo rather than new artwork. It still cannot be
cropped or resized here (no PIL, ImageMagick or `rsvg-convert`; the horizontal lockup is 6208×1331
and useless at 16px).

Still worth capturing the **verbatim** error text and where it appeared (Apps Script editor,
execution log, or browser), because if a direct `.png` is also refused, the honest answer is that an
iframed Apps Script web app's tab icon may not be settable at all — and the item should be dropped
rather than chased.

#### 8. The per-effect ether cost moves into the effect text (supersedes D10)

**Raised by Harvey 2026-09-16:** *"I changed Lark again. Now there are no 'SPECIAL ACTION' effects on
characters and no need for the additional ether cast UI element. Instead I'll add a 'ETHER(4):' tag
at the front of the effect to cover the cost."*

**He has already re-exported, and the working tree holds it** (uncommitted when this was written).
The diff is one row — `03VOI-01CHP-0068` Lark, effect `TRICK SHOT`:

| | Before | After |
|---|---|---|
| `Effect Type 1` | `SPECIAL ACTION \| 4` | `FREE ACTION` |
| `Effect Details 1` | `**QUICKCHARGE**` / `This character gains…` | `**QUICKCHARGE**` / `**ETHER(4)**: This character gains…` |

Two details the prose above doesn't capture, and both matter: the replacement type is **`FREE
ACTION`**, not merely "not special"; and the tag is written **`**ETHER(4)**:`** — bold markdown,
colon after the bold — placed at the start of the effect's *body* line, after the keyword line.

**Audited against the new export, so this is measured, not assumed:**

- **No effect type anywhere carries a `SPECIAL` prefix or a `| N` cost.** Both forms are gone from
  all 200 rows, in both `Effect Type 1` and `Effect Type 2`.
- `ETHER(N)` appears **exactly once** — Lark. This is the first instance of the new convention, not
  a bulk migration.
- **`SPECIAL ACTION` is still a card *Class*, on 102 of the 200 cards** — the single largest class.
  See the namespace trap below.
- All 102 `SPECIAL ACTION` *cards* carry a card-level `Ether` value, and all 12 `CHAMPION`s have it
  blank. So the card-level cost column is untouched by this and keeps working as it did.
- **`validate_cast.py` passes clean on the new export** (200 rows), and `formatRulesText()` already
  turns `**ETHER(4)**:` into `<strong>ETHER(4)</strong>:` for free. So **nothing is broken and
  nothing is urgent** — what follows is about keeping the safety net, not restoring function.

**What to change:**

- **Record the reversal.** D10 said the cost rides on the type and *"a `SPECIAL` always has one, and
  the validator enforces that"*. That is now false. D10 is struck through and **D12** records the new
  convention; D9's "optionally followed by an ether cost (D10)" clause is annotated with it.
- **Turn the dead code into a stale-export detector rather than deleting it.** `parse_effect_type`,
  `EFFECT_COST_PATTERN` and `EFFECT_PREFIXES_REQUIRING_COST` (`validate_cast.py:96-98`, `:140`) now
  match nothing. The file already has the right mechanism for this — `SUPERSEDED_EFFECT_TYPES`,
  which diagnoses pre-D8 spellings with "this is a stale export; re-export the sheet". Add the
  `SPECIAL … | N` form to it and drop `SPECIAL` from `EFFECT_PREFIXES`, so a re-export that still
  carries the old shape is *named* rather than silently accepted.
- **Validate the tag's format.** Catch `ETHER(4)` without the bold, `ETHER (4)`, a missing colon, a
  non-integer, or a tag that isn't at the start of its line. Cheap, and it is the only automated
  check the new convention can have — see the next point.
- **Fix the comment that is now wrong.** `validate_cast.py:87-89` asserts *"FREE costs nothing,
  SPECIAL always costs ether"*. Lark is now a `FREE ACTION` that costs 4 ether, so `FREE` plainly
  refers to the action economy, not to ether. A comment that confidently states the opposite of the
  data is worse than no comment.

**The cost of this change, stated plainly:** D10's rule was a real safety net. A `SPECIAL` type with
no `| N` was a hard error, and that is exactly what caught Lark's dropped cost in the D8 re-export
(§6 item 1b). With the cost living in free text there is **no longer anything that marks an effect as
one that ought to cost ether**, so a dropped `**ETHER(4)**:` is now silent — the validator can check
the tag's shape but never its presence. If that matters, the only real answer is a small explicit
list of cards expected to carry a cost, checked by the validator. Worth asking Harvey, not worth
assuming.

**Nothing to remove for the "additional ether cast UI element."** Searched: the per-effect cost was
never consumed anywhere in this repo. Ether tracking uses the card-level `cost` only
(`calculateCurrentEther()`, `:999`), and the print card renders just `${card.cost}E` plus the class
(`:1545-1547`). The element Harvey retired was on the **card artwork**, which this repo doesn't
generate. So this item is data-convention work only — unless he can point at something specific in
the app, in which case ask rather than guess.

#### Gotchas to carry into the build

- **The quantity badge used to be the blocker for the flush look, and item 3 now removes it.**
  `.card-qty-input` (`:150`) is a child of `.visual-card` at `top: -8px; right: -8px`, i.e. it
  overhangs the art, so `overflow: hidden` — the very rule that gives `contact_sheet.html` its
  flush edges — would clip it. Moving the badge into the caption is what resolves that. **If the
  badge ever moves back over the art, the flush tile breaks again**, so keep the two decisions
  together.
- **A wider container collides with the fixed widget.** `.floating-status-widget` is
  `position: fixed; right: 20px` and does not participate in layout, so nothing stops the container
  sliding under it. At 1200px it never happens. At 1600px it starts on any viewport below ~1980px:
  the container's right edge sits at `100vw/2 + 800` and the widget's left edge at about
  `100vw - 190` (a ~150px box at `right: 20px`), so they meet when `100vw < 1980`. Item 6 makes the widget taller and wider, which
  moves that threshold up. **So if items 1, 3 and 6 all land, build the real two-column shell** —
  content plus a laid-out right rail — instead of a fixed overlay pretending to be one. A centred
  `max-width` cannot buy its way out of this on a 1680px screen; see the arithmetic above.
- **Print is out of scope and must stay that way.** The print grid is its own
  `repeat(3, 63.5mm)` (`:505`, `:667`) and shares nothing with `.card-grid`, so none of this reaches
  paper — but `.print-card*` still lives *outside* `@media print`, so the Chunk 6 rule holds: any
  colour or font that touches a card is `--ink-*` and Arial.
- **`formatRulesText()` escapes before it marks up**, and strips `{M3/Icons/...}` tokens to
  `[Name]`. Reusing it for the caption is safe against sheet content; hand-rolling a second
  formatter would not be, and would be the twin-function trap again.
- **`.card-grid` is used by six grids**, including `#talismans-grid` and `#champion-grid` (`:767-793`).
  A change to the shared class hits all six — the champion row and the talisman row included, where
  a caption full of effect text may not be wanted. Expect to split a `.card-grid--captioned`
  variant rather than changing the base class.

**Test:** desktop at ≥1400px — five cards per row, art flush to the tile edge, art bigger than
before, and the ability text readable in the caption without hovering or clicking anything. Then
1100px, 900px and 600px, checking the column counts above and that the print/export buttons survive
the widget's reflow at 1100px.

Then the two things most likely to be got wrong, both on a **phone** (below 600px):

1. The ability text is **hidden**, and the card art is one-per-row and large enough to read the
   baked-in effects instead.
2. The quantity badge is **still there and still works** on Basic Familiars, even though the text
   beside it is hidden — set a quantity, confirm it registers against the Ether tracker, and confirm
   tapping the badge does not also toggle the card's selection.

Then: confirm Montserrat is loading rather than the fallback, `h1`/`h2` are still Cinzel, and
`python3 dextrous/validate_cast.py` still passes. Finally print-preview once and confirm nothing
changed on paper. Lark (`03VOI-01CHP-0068`) is the card to look at for the `**ETHER(4)**:` tag —
it should read as bold inline text in the caption, and it is the only card in the set that has one.

**Done when:** a full cast fits in appreciably less scrolling, a card's effects can be read on a
desktop without opening anything, a phone can still set quantities, and print preview is
byte-for-byte the same as before the chunk.

**Decided 2026-09-16:** item 2 is **option 1 alone**, caption hidden below 600px; the quantity badge
**moves into the caption box**; and item 8 records the `**ETHER(N)**:` convention.

**Still open — one decision, and it changes the build:**

1. **Container width on large screens, and with it whether the tracker widget becomes a laid-out
   right rail** (recommendation: yes to both — 1600px wide with a real rail gives 5 across at
   ~292px, bigger than today's 4 across at 260px). Keeping the fixed overlay caps how wide the
   content can safely get, and on a 1680px screen forces the cards *smaller* than today. Item 6
   pushes the same way, since the print/export buttons are moving into that widget.

**Worth asking, not worth assuming:** whether the validator should carry an explicit list of cards
expected to have an `ETHER(N)` tag, to replace the presence check D10 used to give for free (item 8).

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

3. ~~**Copy the branding assets**~~ — **mostly done.** The PDF (2026-09-15), the six dominion
   colours (`Dominion Colours.txt`, 2026-09-15) and the horizontal logo SVG are all in
   `assets/branding/`. **Outstanding: a logo PNG**, for the favicon and for TTS, which takes raster
   only. Path and Explorer instructions are in §3.6. Blocks part of Chunk 7 only.
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
