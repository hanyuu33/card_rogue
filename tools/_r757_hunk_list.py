# -*- coding: utf-8 -*-
"""把 git diff 按 hunk 切开，打印清单供人工分类（不改任何东西）。"""
import re
import sys
import pathlib

patch = pathlib.Path("_bk_r757_full.patch").read_text(encoding="utf-8", errors="replace")
lines = patch.split("\n")

files = []          # [(path, header_lines, [hunk_lines...])]
cur = None
hunk = None
for ln in lines:
    if ln.startswith("diff --git "):
        cur = {"path": ln.split(" b/")[-1], "header": [ln], "hunks": []}
        files.append(cur)
        hunk = None
    elif cur is None:
        continue
    elif ln.startswith("@@"):
        hunk = [ln]
        cur["hunks"].append(hunk)
    elif hunk is not None:
        hunk.append(ln)
    else:
        cur["header"].append(ln)

total = 0
for f in files:
    print("### %s  (%d hunks)" % (f["path"], len(f["hunks"])))
    for i, h in enumerate(f["hunks"]):
        total += 1
        body = [x for x in h[1:] if x and x[0] in "+-"]
        snippet = " ".join(x.strip()[:70] for x in body[:2])
        print("  [%d] %s | %s" % (i, h[0][:40], snippet[:150]))
print("TOTAL HUNKS =", total)
