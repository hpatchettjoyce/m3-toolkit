#!/usr/bin/env python3
"""Copy the master sheet's Cast tab from the M3 Source Exporter's output into the repo.

This replaces the manual "File -> Download -> CSV" step. The "M3 Source Exporter" Apps
Script (05_AI Agent Support/_tools/source-exporter) already writes every tab of the master
sheet, "02_Card and Dominion Effects", to Drive as CSV every 15 minutes. Drive for desktop
syncs that folder to G:, so this script only copies the file over `M3_TTS_DB - Cast.csv`
and says how fresh it is and which cards changed.

    python3 dextrous/pull_cast.py [--source PATH] [--out PATH]

The export reflects the sheet as of its last run. After editing the sheet, either wait for
the next 15-minute run or run `pullNow` in the exporter's Apps Script editor; the
"exported" time printed here shows which you got. Run validate_cast.py next, as before.

Exits 1 when the export is missing, unreadable or marked failed.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO_ROOT / "M3_TTS_DB - Cast.csv"
SOURCES = Path("/mnt/g/My Drive/05_GAME DESIGN CONCEPTS/Monumentum/05_AI Agent Support/02_Sources")
SHEET = "02_Card and Dominion Effects"
DEFAULT_SOURCE = SOURCES / SHEET / "Cast.csv"
MANIFEST = SOURCES / "_manifest.json"

REMOUNT_HINT = (
    "G: looks unmounted in WSL. Remount it with:\n"
    "  wsl.exe -d Ubuntu -u root -- umount -l /mnt/g; wsl.exe -d Ubuntu -u root -- mount -t drvfs G: /mnt/g -o uid=1000,gid=1000"
)


def fail(message: str) -> None:
    print(f"FAILED — {message}")
    sys.exit(1)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except FileNotFoundError:
        fail(f"not found: {path}")
    except OSError as err:  # a stale drvfs mount raises "No such device"
        fail(f"can't read {path} ({err.strerror}).\n{REMOUNT_HINT}")
    raise AssertionError  # unreachable


def ago(stamp: str) -> str:
    then = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    minutes = int((datetime.now(timezone.utc) - then).total_seconds() // 60)
    if minutes < 60:
        return f"{minutes} min ago"
    if minutes < 48 * 60:
        return f"{minutes // 60} h ago"
    return f"{minutes // (24 * 60)} days ago"


def report_freshness(manifest_path: Path) -> None:
    """Print when the sheet was last exported; stop if the exporter recorded an error for it."""
    manifest = json.loads(read_text(manifest_path))
    entry = next((s for s in manifest.get("sources", []) if s.get("path") == SHEET), None)
    if entry is None:
        fail(f'the exporter manifest has no "{SHEET}" entry')
    if entry.get("error"):
        fail(f"the exporter's last attempt on the sheet failed: {entry['error']}")
    print(f"  sheet last edited {entry['modifiedTime'][:16].replace('T', ' ')} UTC ({ago(entry['modifiedTime'])})")
    print(f"  exported          {entry['exportedAt'][:16].replace('T', ' ')} UTC ({ago(entry['exportedAt'])})")
    print(f"  exporter run      {manifest.get('status', '?')}, finished {ago(manifest.get('finishedAt') or manifest['startedAt'])}")


def rows_by_id(text: str) -> dict[str, list[str]]:
    rows = list(csv.reader(io.StringIO(text)))
    if not rows:
        return {}
    header = rows[0]
    if "ID" not in header:
        return {}
    i = header.index("ID")
    return {r[i]: r for r in rows[1:] if len(r) > i and r[i]}


def report_changes(old_text: str, new_text: str) -> None:
    old, new = rows_by_id(old_text), rows_by_id(new_text)
    added = [k for k in new if k not in old]
    removed = [k for k in old if k not in new]
    changed = [k for k in new if k in old and new[k] != old[k]]
    if not (added or removed or changed):
        print("  no card changes since the last pull")
        return
    name = lambda rows, k: rows[k][1] if len(rows[k]) > 1 else ""  # column B is Name
    for label, keys, rows in (("changed", changed, new), ("added", added, new), ("removed", removed, old)):
        if keys:
            print(f"  {label} ({len(keys)}): " + ", ".join(f"{k} {name(rows, k)}" for k in keys))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="the exporter's Cast.csv")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"default: {DEFAULT_OUT.name}")
    args = parser.parse_args()

    print(f"Pulling {args.source.name} from the exporter's {SHEET} export")
    if args.source == DEFAULT_SOURCE:
        report_freshness(MANIFEST)
    new_text = read_text(args.source)
    old_text = args.out.read_text(encoding="utf-8-sig") if args.out.exists() else ""
    report_changes(old_text, new_text)
    # Written as exported (no BOM, LF endings); every reader in dextrous/ accepts both forms.
    args.out.write_text(new_text, encoding="utf-8", newline="")
    print(f"Wrote {args.out.name}. Next: python3 dextrous/validate_cast.py")


if __name__ == "__main__":
    main()
