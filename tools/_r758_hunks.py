# -*- coding: utf-8 -*-
"""R758: 列出工作区 diff 的每个 hunk，并按 R758 关键字标记归属（mine / other / mixed）。"""
import re
import subprocess

FILES = [
    "scripts/game_engine.gd",
    "scripts/battle_scene.gd",
    "scripts/test_engine.gd",
    "scripts/game_levels.gd",
    "cards.json",
    "i18n/cards_en.json",
    "i18n/cards_ja.json",
    "i18n/cards_es.json",
    "i18n/zh_canonical.json",
    "i18n/interface_en.json",
    "i18n/interface_ja.json",
    "i18n/interface_es.json",
    "i18n/interface_zh_canonical.json",
]

MARK = [
    "R758", "9260", "9261", "9262", "计量工坊", "常数测量员", "精密计算者",
    "负载增量员", "metrology_works", "survey_beam", "compute_cap", "deck_gift",
    "SURVEYOR", "LOADER_", "CALCULATOR", "fx_survey_beam", "METROLOGY_WORKS",
]

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")


def hunks_of(path):
    out = subprocess.run(["git", "diff", "-U3", "--", path],
                         capture_output=True, text=True, encoding="utf-8").stdout
    cur = None
    res = []
    for ln in out.splitlines():
        m = HUNK.match(ln)
        if m:
            if cur:
                res.append(cur)
            cur = {"old": int(m.group(1)), "new": int(m.group(3)), "lines": [ln]}
        elif cur is not None:
            cur["lines"].append(ln)
    if cur:
        res.append(cur)
    return res


def main():
    for path in FILES:
        hs = hunks_of(path)
        if not hs:
            continue
        print("=== %s  hunks=%d" % (path, len(hs)))
        for h in hs:
            body = [l for l in h["lines"][1:] if l[:1] in "+-"]
            mine = [l for l in body if any(k in l for k in MARK)]
            tag = "MINE " if mine and len(mine) == len(body) else ("mixed" if mine else "other")
            print("  old=%-6d new=%-6d %-5s (+%d/-%d) mine=%d" % (
                h["old"], h["new"], tag,
                sum(1 for l in body if l.startswith("+")),
                sum(1 for l in body if l.startswith("-")), len(mine)))
            if mine:
                for l in mine[:6]:
                    print("      %s" % l[:150])


if __name__ == "__main__":
    main()
