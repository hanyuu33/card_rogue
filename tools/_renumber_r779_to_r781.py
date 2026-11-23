# -*- coding: utf-8 -*-
"""改号：本轮从 R779 让到 R781（并行线已占 R779 工具栏描述 / R780 赫尔墨斯）。

只动**我自己改过**的 7 个脚本 + 我的补丁脚本文件名；并行线的 battle_scene / placement /
cards_* / zh_canonical 一律不碰。test_engine.gd 里还有小写 `r779_*` 测试变量要一起改。
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

FILES = [
    "scripts/daily_modifiers.gd",
    "scripts/daily_challenge.gd",
    "scripts/run_state.gd",
    "scripts/rogue_map.gd",
    "scripts/event_scene.gd",
    "scripts/game_engine.gd",
    "scripts/test_engine.gd",
]

total = 0
for rel in FILES:
    raw = open(rel, "rb").read()
    before = raw
    raw = raw.replace(b"R779", b"R781")
    if rel == "scripts/test_engine.gd":
        # 小写只出现在我加的测试变量 / 函数名上（`_test_r779`、`r779_drain` 之类）
        raw = raw.replace(b"r779", b"r781")
    n = before.count(b"R779") + (before.count(b"r779") if rel.endswith("test_engine.gd") else 0)
    if raw != before:
        open(rel, "wb").write(raw)
    total += n
    print("  %-32s 改 %d 处 | 残留 R779=%d r779=%d" % (
        rel, n, raw.count(b"R779"), raw.count(b"r779")))

# 我的补丁脚本改名（并行线那几个 _patch_r779_tooltip / test2 / _shot_r779_revelator 不动）
MINE = ["_patch_r779_draw.py", "_patch_r779_draw_fix.py", "_patch_r779_i18n.py",
        "_patch_r779_narrative.py", "_patch_r779_test_fix.py"]
for fn in MINE:
    src = os.path.join("tools", fn)
    if not os.path.exists(src):
        print("  [skip] %s 不存在" % fn)
        continue
    raw = open(src, "rb").read().replace(b"R779", b"R781").replace(b"r779", b"r781")
    dst = os.path.join("tools", fn.replace("r779", "r781"))
    open(dst, "wb").write(raw)
    os.remove(src)
    print("  %s -> %s" % (fn, os.path.basename(dst)))

print("合计替换 %d 处" % total)
