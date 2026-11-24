# -*- coding: utf-8 -*-
"""R756: 把指定文件的 git diff 切成 hunk，逐个打印，便于判断归属（我的 R756 vs 并行线 R757）。"""
import re
import subprocess
import sys

FILES = sys.argv[1:] or [
    "scripts/battle_scene.gd", "scripts/run_state.gd", "scripts/game_engine.gd",
    "scripts/event_scene.gd", "scripts/field_state.gd", "scripts/test_engine.gd",
    "scripts/test_reward.gd", "cards.json", "relics.json",
]

HDR = re.compile(r"^diff --git ")
HUNK = re.compile(r"^@@")


def split_hunks(text):
    """返回 (file_header_lines, [hunk_text, ...])"""
    lines = text.splitlines(keepends=True)
    head, hunks, cur = [], [], None
    for ln in lines:
        if HDR.match(ln):
            head.append(ln)
        elif HUNK.match(ln):
            if cur is not None:
                hunks.append("".join(cur))
            cur = [ln]
        elif cur is None:
            head.append(ln)
        else:
            cur.append(ln)
    if cur is not None:
        hunks.append("".join(cur))
    return head, hunks


for f in FILES:
    r = subprocess.run(["git", "diff", "--", f], capture_output=True)
    text = r.stdout.decode("utf-8", "replace")
    if not text.strip():
        print("### %s : (no diff)" % f)
        continue
    head, hunks = split_hunks(text)
    print("=" * 70)
    print("### %s : %d hunks" % (f, len(hunks)))
    for i, h in enumerate(hunks):
        marks = []
        for kw in ("R756", "R757", "APPLE_HEAL_PCT", "APPLE_MAX_HP", "代偿",
                   "Telemetry", "COMP_COST", "_tele_", "curse_raise",
                   "DIVINATION", "CORE_COMP"):
            if kw in h:
                marks.append(kw)
        added = [l for l in h.splitlines() if l.startswith("+") and not l.startswith("+++")]
        removed = [l for l in h.splitlines() if l.startswith("-") and not l.startswith("---")]
        print("  [%02d] %-42s +%d/-%d  marks=%s" % (
            i, h.splitlines()[0][:42], len(added), len(removed), ",".join(marks) or "-"))
