#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Godot 4 import-cache hygiene for card_rogue.

Why this exists
---------------
Godot exports .godot/imported/*.ctex into the APK as
assets/.godot/imported/*.ctex. When a source image is deleted (one-off
ImageGen raw dumps, renamed candidates, old backups), its imported .ctex is
NOT removed -- Godot keeps the stale blob on disk forever. R563 cleanup
removed 141 such disk orphans (23.2 MiB); those blobs were NOT in the export
list, so the APK size did not change (326,140,291 B before and after).

NOTE: APK entry names for non-ASCII source files come back as mojibake, so
exact-name matching falsely reported 13 "orphans" inside the R563 APK.
Matching by the encoding-proof <md5>.<ext> suffix shows 0 real orphans.
Both the cleaner and the APK audit use that suffix as a fallback (blob_key()).

This script builds a whitelist from every surviving .import file's
dest_files (res://.godot/imported/...) and removes only blobs that no
.import references. Valid caches are kept, so Godot does NOT need a full
re-import (fast, safe, idempotent).

Usage
-----
    python tools/clean_godot_import_cache.py                    # dry-run
    python tools/clean_godot_import_cache.py --apply           # delete orphans
    python tools/clean_godot_import_cache.py --apply --full    # wipe ALL cache
    python tools/clean_godot_import_cache.py --audit-apk dist/DuckCardsRogue_R563.apk

--full makes Godot re-import every asset on the next export (slow, but the
nuclear option when the cache itself looks corrupt). build_apk.sh calls the
default orphan mode; override with CARDROGUE_IMPORT_CACHE=full|orphan|skip.
"""

import argparse
import os
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".godot" / "imported"
SKIP_DIRS = {".git", ".godot", "dist", "android", "export", "_pkg_hold", ".workbuddy"}
DEST_RE = re.compile(r'res://\.godot/imported/([^"\s,\]]+)')
MIN_WHITELIST = 200  # sanity guard: never wipe a cache we failed to read


def blob_key(name):
    """Encoding-proof identity: Godot names blobs <source>-<md5>.<ext>.

    Non-ASCII source names get mojibaked in APK entry names, but the md5
    suffix survives. Compare by suffix when exact names do not match.
    """
    tail = name.rsplit("/", 1)[-1]
    return tail.rsplit("-", 1)[-1] if "-" in tail else tail


def is_live(name, names, keys):
    return name in names or blob_key(name) in keys


def whitelist():
    """(names, md5-suffix keys) of blobs still referenced by live .import files."""
    live = set()
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if not name.endswith(".import"):
                continue
            try:
                text = (Path(dirpath) / name).read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for dest in DEST_RE.findall(text):
                live.add(dest)
                # Godot writes a companion <same-stem>.md5 next to each .ctex
                live.add(str(Path(dest).with_suffix(".md5")))
    return live, {blob_key(n) for n in live}


def cache_files():
    if not CACHE.is_dir():
        return []
    return [p for p in CACHE.iterdir() if p.is_file()]


def do_clean(apply, full):
    if not CACHE.is_dir():
        print("[cache] .godot/imported not present, nothing to clean")
        return 0
    live, keys = whitelist()
    if len(live) < MIN_WHITELIST:
        print("[cache] FATAL: only %d live dest refs, refuse to touch cache" % len(live))
        return 2
    files = cache_files()
    if full:
        doomed, kept = files, []
    else:
        doomed = [p for p in files if not is_live(p.name, live, keys)]
        kept = [p for p in files if is_live(p.name, live, keys)]
    bytes_freed = sum(p.stat().st_size for p in doomed)
    print("[cache] live refs=%d  cache files=%d  keep=%d  orphan=%d (%.1f MiB)"
          % (len(live), len(files), len(kept), len(doomed), bytes_freed / 1048576.0))
    if not apply:
        print("[cache] dry-run only, pass --apply to delete")
        for p in doomed[:5]:
            print("        e.g. %s" % p.name)
        return 0
    for p in doomed:
        try:
            p.unlink()
        except OSError as exc:
            print("[cache] WARN cannot remove %s: %s" % (p.name, exc))
    print("[cache] removed %d orphan blobs (%.1f MiB)%s"
          % (len(doomed), bytes_freed / 1048576.0,
             "; full wipe, Godot will re-import" if full else ""))
    return 0


def do_audit_apk(apk):
    apk = Path(apk)
    if not apk.is_file():
        print("[cache] FATAL: APK not found: %s" % apk)
        return 2
    live, keys = whitelist()
    if len(live) < MIN_WHITELIST:
        print("[cache] FATAL: only %d live dest refs, refuse to audit" % len(live))
        return 2
    with zipfile.ZipFile(apk) as zf:
        ctex = [n for n in zf.namelist()
                if n.startswith("assets/.godot/imported/") and n.endswith(".ctex")]
        orphan = [n for n in ctex if not is_live(n.rsplit("/", 1)[-1], live, keys)]
        size = sum(zf.getinfo(n).file_size for n in orphan)
    print("[cache] APK ctex=%d  orphan=%d (%.1f MiB)"
          % (len(ctex), len(orphan), size / 1048576.0))
    for n in orphan[:5]:
        print("        e.g. %s" % n.rsplit("/", 1)[-1])
    return 1 if orphan else 0


def main():
    ap = argparse.ArgumentParser(description="clean stale Godot import cache")
    ap.add_argument("--apply", action="store_true", help="actually delete (default: dry-run)")
    ap.add_argument("--full", action="store_true", help="wipe ALL imported blobs, not just orphans")
    ap.add_argument("--audit-apk", metavar="APK", help="check an APK for orphan .ctex; exit 1 if any")
    args = ap.parse_args()
    if args.audit_apk:
        return do_audit_apk(args.audit_apk)
    return do_clean(args.apply, args.full)


if __name__ == "__main__":
    sys.exit(main())
