# -*- coding: utf-8 -*-
"""R754：把本轮自己的 `R753` 标记改成 `R754`（R753 已被「图鉴锁」那一轮占用）。
规则：只改本轮碰过的文件，且 **跳过 gallery_scene.gd** 与 test_engine.gd 里
图鉴块（行号 >= 75140）—— 那些是 R753 那轮自己的标记，不能动。
按行处理，保持每行原行尾。"""
import io

ROOT = "E:/work/card_rogue/"
FILES = [
    "scripts/battle_scene.gd",
    "scripts/event_scene.gd",
    "scripts/game_engine.gd",
    "scripts/game_layers.gd",
    "scripts/run_save.gd",
    "scripts/run_state.gd",
    "scripts/test_engine.gd",
    "scripts/test_trap_input.gd",
    "scripts/test_traps.gd",
    "scripts/trap_art.gd",
    "scripts/trap_data.gd",
    "scripts/trap_repo.gd",
]
SKIP_AFTER = {"scripts/test_engine.gd": 75140}   # 1-based 行号

total = 0
for rel in FILES:
    raw = io.open(ROOT + rel, "r", encoding="utf-8", newline="").read()
    lines = raw.split("\n")
    skip_from = SKIP_AFTER.get(rel)
    n = 0
    for i, ln in enumerate(lines):
        if skip_from is not None and (i + 1) >= skip_from:
            continue
        if "R753" in ln:
            lines[i] = ln.replace("R753", "R754")
            n += 1
    if n:
        io.open(ROOT + rel, "w", encoding="utf-8", newline="").write("\n".join(lines))
        print("%-32s %d lines" % (rel, n))
        total += n
print("total replaced:", total)

# 复核：改完再数一遍
import subprocess
for rel in FILES:
    b = io.open(ROOT + rel, "r", encoding="utf-8", newline="").read()
    print("%-32s R753=%d R754=%d crlf=%d lf=%d" % (
        rel, b.count("R753"), b.count("R754"), b.count("\r\n"), b.count("\n")))
