---
name: handover
description: Write the end-of-chunk handover note that lets a fresh session pick up this work with no memory of it. Use when finishing a chunk of the M3 upgrade plan, when the user says "write the handover", "wrap up this chunk", "I'm going to clear context", or before any deliberate context reset.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# /handover — write the end-of-chunk handover note

The next session starts with **no memory of this one**. It reads the plan and your handover, and
nothing else. Everything it needs must be in the file.

## When this runs

Normally at the end of a chunk, *before* the user manually tests. Write it first, then amend it with
the test result — if the test fails, that failure detail is the most valuable thing in the file.

It's also valid mid-chunk when the user wants to stop early. Say so plainly in that case; a partial
chunk with an honest seam is fine, a partial chunk described as complete is not.

## Step 1 — gather facts, don't recall them

Run these rather than writing from memory. Memory of a long session is exactly what's unreliable
here.

```bash
git branch --show-current
git log --oneline -5
git status --short
git diff --stat HEAD~1        # or against the chunk's starting commit
```

Read the plan's section for the chunk you just did, so "NOT done" is measured against what was
actually specified rather than what you remember intending.

## Step 2 — find the target path

- Plan file: `UPGRADE_PLAN.md` at the repo root (the source of truth).
- Handover directory: `handover/`. Template at `handover/TEMPLATE.md`.
- Filename: `handover/CHUNK_<n>_HANDOVER.md`, zero-padded to two digits (`CHUNK_03_HANDOVER.md`).
- If a file for this chunk already exists, **amend it, don't overwrite it** — that's the
  post-manual-test path, and the earlier content is the record of what was claimed before testing.

## Step 3 — write it

Follow `handover/TEMPLATE.md`. Fill every section; write "None" rather than deleting a heading, so
the next session can tell the difference between "nothing to report" and "not considered".

What separates a useful handover from a useless one:

- **Decisions need their reasons, and what they rule out.** Git already has the diffs. "Normalised
  the class at the parse boundary rather than changing 40 frontend comparisons, because the frontend
  is 1734 lines and untestable locally" is useful. "Changed class handling" is not.
- **Verified facts, with the command that verified them.** If you didn't run it, don't claim it.
  Distinguish "confirmed by running X" from "should work".
- **Gotchas are the highest-value section.** Anything that cost you time to discover, that the code
  doesn't make obvious, goes here — a silent failure mode, a misleading comment, a function that
  isn't called from where you'd expect.
- **"Next session starts here" must be a concrete first action**, not a restatement of the chunk
  title. Name the file and what to do to it.
- **If a plan finding turned out to be wrong, fix `UPGRADE_PLAN.md` itself** and note that you did.
  Later sessions trust §1–§3; a stale finding there does real damage.

## Step 4 — commit

Commit the handover with the chunk's code, on the chunk's branch. Never to `main`, never force-push.
Push if there's a remote, so the note survives the worktree being deleted.

## Step 5 — tell the user what to test

End your reply with the manual test steps from the plan's chunk section, as a short numbered list
they can work through. This is the only part they act on, so keep it concrete: what to click, what
to look at, what the correct result is. Name the specific cards, IDs or dominions to check where the
plan does — "open Caldrack (`01RHA-03FAM-0012`), which has both effects populated" beats "check a
card renders".

Then state plainly whether the chunk is complete or partial, and what you'd expect to break.

## Step 6 — after they report back

Amend the handover's **Tested** section with what actually happened, and update **Chunk status**.
If the test failed, record the symptom verbatim before attempting a fix — the next session may be
the one fixing it.
