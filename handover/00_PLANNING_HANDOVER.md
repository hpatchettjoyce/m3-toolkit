# Planning handover — survey and plan complete, Chunk 0 is next

**Session date:** 2026-09-14
**Commit:** see `git log` on this branch  **Branch:** `worktree-upgrade-plan`
**Chunk status:** complete (planning only — no production code touched yet)

## What changed

- `UPGRADE_PLAN.md`: the full plan. Survey of what the data restructure breaks, 7 findings, 8 chunks,
  handover protocol. **This is the source of truth — read it before doing anything.**
- `handover/TEMPLATE.md`: the per-chunk handover template.
- `assets/branding/README.md`: placeholder plus the Windows path for dropping brand assets in.
- `M3_TTS_DB - Cast.csv`: the new single-sheet export, 200 rows. Refreshed 2026-09-14 to pick up
  Harvey's `Ignatious` -> `Ignatius` and `MANOEUVER` -> `MANOEUVRE` corrections.
- `dextrous/MonuMentuM 14-09-2026.json`: the new 200-card `Deck Cast` saved object, not yet injected.

No code in `webapp/`, `tts/` or `dextrous/*.py` has been modified.

## Decisions made

All six are logged in `UPGRADE_PLAN.md §1.1` as D1–D6. **Treat them as closed.** The two that most
change the shape of the work:

- **D2 — health derives from the `Class` name, never from the ID.** The ID scheme changed for sorting
  only. This means the `CLASS_MAP` segment tables in `Floating_Health_Tracker.lua` and
  `Model_ID_Injector.lua` get **deleted**, not ported to the new codes. Chunk 1 must write each
  card's class into the deck card's `Description` so Chunk 5 has it.
- **D1 — the `ae`/comma forms in `Role Details` are intentional**, not typos. Dextrous can't take
  commas and the `æ` ligature is avoided. Normalised matching is mandatory, on **both sides** of the
  comparison (champion `Name` still carries the comma and the ligature).

## Tested

Planning session, so this is data verification rather than a manual test. Against the refreshed CSV:

- 200 rows, 200 unique IDs -> OK
- Class census `CHAMPION` 12 / `FAMILIAR` 68 / `MINION` 6 / `TALISMAN` 12 / `SPECIAL ACTION` 102 -> OK
- Role census blank 176 / `COMPANION` 12 / `SIGNATURE` 12 -> OK
- **All 24 companion/signature links resolve under the §3.1 normalisation, 0 unresolved.** Prototyped
  with NFKD + ligature map + comma/apostrophe/period strip + casefold, scoped within dominion. The
  Chunk 0 validator should reproduce this result exactly — if it doesn't, the normalisation differs.
- All 97 populated `Effect N - Name` fields match the strict `{EffectName:X} {EffectType:Y}` shape,
  0 non-conforming -> OK
- Deck JSON: 200 `ContainedObjects`, 200 `DeckIDs`, 5 `CustomDeck` sheets (8x6), all `Nickname` empty
  and all `GMNotes` null -> matches CSV 1:1, ready for positional injection

## NOT done / deliberately deferred

- Everything in Chunks 0–7. No production code touched.
- `CLAUDE.md` and `PROJECT_NOTES.md` still describe the two-tab architecture. Deliberate — they get
  updated in the §7 clean-up pass after Chunk 5, not before, so they stay accurate for whoever is
  mid-migration.
- The old CSVs and old saved objects are still present, also per §7.

## Gotchas found

- **`Cinderhulk` (`01RHA-03FAM-0006`) has a casing artifact**: `{EffectType:| *ATTACK manoeuvre
  ACTION*}`, lowercase mid-label where every other payload is uppercase. Left over from the spelling
  correction. Flagged to Harvey as action §6.2 — **fix the cell, don't work around it in the
  renderer**. Lowercase `manoeuvre` in the *Details* columns is correct prose and must be left alone.
- **`generate_card_images.py` reads `"Name (str)"` and `"ID (str)"` literally.** The new headers
  dropped the type suffixes, so it will silently inject **empty strings** rather than erroring. The
  backend survives this because `findColumnIndex()` already accepts both spellings; the compiler does
  not. First thing to fix in Chunk 1.
- **`champ_<index>` / `unit_<index>` / `sp_<index>` and `CardImages.gs` are both row-index-keyed.**
  Dominion grouping changes every index. Art would attach to the wrong cards — see §3.3.
- **The Apps Script global namespace is flat.** Two `.gs` files defining the same function silently
  override each other; this has bitten the project before. Don't add a second card-fetching function.
- **`G:` is not mounted** in this WSL environment, only `/mnt/c`. Brand assets must be copied in.
- Driplet and Huskling have **blank** Ether, so `parseInt('') || 0` keeps them out of the recruitable
  basics list. Confirm this still holds in Chunk 3; don't "fix" it.

## Next session starts here

- **Just run `/resume`.** It reads the plan and this file, verifies the repo state, checks the §6
  prerequisites, and starts Chunk 0. End the session with `/handover`.
- If reading manually instead: `UPGRADE_PLAN.md` (all of §1–§3, then §4 Chunk 0), then this file.
- First action: write `dextrous/validate_cast.py` per Chunk 0, including the normalising name-match
  as a reusable function — Chunk 2 ports the same logic into `main.gs`, and the two must agree.
- Expected result: passes clean on the current data, all 24 links resolving. To prove the link check
  isn't passing vacuously, temporarily corrupt one `Role Details` value, confirm it's reported,
  then revert.
- Note for Harvey at the end of the chunk: whether the `Cinderhulk` cell has been fixed yet.
