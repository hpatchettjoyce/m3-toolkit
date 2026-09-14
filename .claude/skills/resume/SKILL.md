---
name: resume
description: Pick up the M3 upgrade plan in a fresh session — read the plan and the latest handover, verify the repo actually matches what they claim, then start the next chunk. Use at the start of a new session, or when the user says "resume", "carry on", "pick up where we left off", or names a chunk to work on.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# /resume — pick up where the last session stopped

Optional argument: a chunk number (`/resume 3`). Without one, resume from wherever the handovers say
the work stopped.

## Step 1 — read, in this order

1. **`UPGRADE_PLAN.md` §1 and §1.1.** §1.1 is the closed-decisions log. Those decisions are settled —
   do not re-litigate them or re-propose alternatives that were already rejected.
2. **§2 and §3** — what changed in the data, and the findings. Skim §2, read §3 properly; it's where
   the silent failure modes are written up.
3. **The latest handover.** `ls handover/` and take the **highest chunk number**, not the newest
   mtime — a file touched later isn't necessarily further along. Read it in full.
4. **The plan's section for the chunk you're about to do.**

If the handover and the plan disagree, the handover is more recent about *state*, the plan is
authoritative about *intent*. Say so and ask rather than guessing, if it matters.

## Step 2 — verify the state instead of trusting it

The handover describes the repo as it was. Confirm it still is:

```bash
git branch --show-current
git log --oneline -3
git status --short
```

Then check anything the handover depends on:

- If it says a chunk is complete, spot-check that the change is actually present.
- If it names a file, function, constant or flag, **confirm it still exists** before building on it.
- If a validator or script exists, run it. A clean run is the cheapest possible confirmation that
  the data and pipeline are where the handover says.

Report any mismatch immediately rather than working around it. A handover that's wrong about state
is a bigger problem than the chunk itself.

## Step 3 — check the human's prerequisites

Several chunks are blocked on something only the user can do (fixing a spreadsheet cell, copying in
brand assets, re-exporting a CSV, rearranging the TTS table). `UPGRADE_PLAN.md §6` lists them.

Check whether the ones your chunk needs are actually done — don't assume, and don't assume they
aren't either. Verify where you can: grep the CSV for the corrected value, `ls` the asset directory.
If a prerequisite is genuinely missing, do everything that doesn't depend on it, then say exactly
what's needed.

## Step 4 — orient the user before doing work

Open with a short summary, in your own words:

- Where the work stopped, and whether the last chunk passed its manual test
- Which chunk is next, and what it will change
- Anything blocking, and anything the previous session flagged as a gotcha that affects this chunk

Keep it to a few lines. The user has no more memory of the last session than you do, and this is
what re-orients them.

## Step 5 — then do the chunk

Work to the plan's spec for that chunk. If the spec turns out to be wrong, fix `UPGRADE_PLAN.md`
as well as the code, and flag it — later sessions trust §1–§3.

Stop and ask if the handover says **blocked**, or if the chunk's prerequisites aren't met and
proceeding would produce work that has to be redone.

## Step 6 — finish with `/handover`

Don't hand-roll the handover note; invoke the `handover` skill so the format and the quality bar
stay consistent across sessions.
