# -*- coding: utf-8 -*-
"""撞号修正：本轮 R805 → R807（远端并行线已占 R805 蜂蜜 / R806 法术卷轴）。

必须改的原因不只是编号好看：远端 test_engine.gd 里也有 func _test_r805()（蜂蜜那条），
合并后同文件出现两个同名函数 → GDScript 解析直接失败。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TARGETS = [
    "scripts/event_scene.gd",
    "scripts/game_engine.gd",
    "scripts/game_layers.gd",
    "scripts/run_state.gd",
    "scripts/test_engine.gd",
    "scripts/test_reward.gd",
    "i18n/validate_event_ui.py",
    "i18n/validate_narrative.py",
    "i18n/validate_spanish.py",
]

total = 0
for rel in TARGETS:
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        print("SKIP %s（不存在）" % rel)
        continue
    raw = io.open(p, "rb").read()
    s = raw.decode("utf-8")
    n0 = s.count("R805") + len(re.findall(r"\br805_", s)) + s.count("_test_r805")
    s2 = s.replace("_test_r805", "_test_r807")
    s2 = s2.replace("R805", "R807")
    s2 = re.sub(r"\br805_", "r807_", s2)
    n1 = s2.count("R805") + len(re.findall(r"\br805_", s2)) + s2.count("_test_r805")
    if n1 != 0:
        print("FAIL %s 残留 %d 处" % (rel, n1))
        sys.exit(1)
    if s2 != s:
        io.open(p, "wb").write(s2.encode("utf-8"))
        print("OK   %-32s %d 处" % (rel, n0))
        total += n0
    else:
        print("--   %-32s 无改动" % rel)

# 行尾复核
for rel in TARGETS:
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        continue
    b = io.open(p, "rb").read()
    crlf, lf = b.count(b"\r\n"), b.count(b"\n")
    tag = "PURE-CRLF" if crlf == lf else ("PURE-LF" if crlf == 0 else "MIXED!!")
    if tag == "MIXED!!":
        print("!!! %s 行尾混了" % rel)
        sys.exit(1)

print("共替换 %d 处" % total)
