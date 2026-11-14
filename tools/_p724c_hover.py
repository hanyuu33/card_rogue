# -*- coding: utf-8 -*-
"""R724c：悬停判定也认「选中放大」—— 放大后的卡整张都能悬停出左栏说明（仍不含抬手，防闪）。"""
import sys

CHECK_ONLY = "--check-only" in sys.argv
P = "scripts/battle_scene.gd"

old = (
    "\t# ② 己方手牌（会重叠 → 从最上层往前找）\n"
    "\tif _hover_card == null:\n"
    "\t\tfor i in range(engine.state.hand.size() - 1, -1, -1):\n"
    "\t\t\tif _hand_hit(i, pos):\n"
)
new = (
    "\t# ② 己方手牌（会重叠 → 从最上层往前找）\n"
    "\t# R724：悬停跟「选中放大」走（整张放大后的卡都能查出说明），但**不含**悬停抬手 ——\n"
    "\t# 抬手由悬停本身驱动，算进来就成了「抬起 → 点不在卡上 → 落下 → 又命中」的闪。\n"
    "\tif _hover_card == null:\n"
    "\t\tfor i in range(engine.state.hand.size() - 1, -1, -1):\n"
    "\t\t\tif _hand_hit_geom(i, pos, 0.0, _is_hand_selected(i)):\n"
)

data = open(P, "rb").read()
o = old.replace("\n", "\r\n").encode("utf-8")
n = new.replace("\n", "\r\n").encode("utf-8")
c = data.count(o)
assert c == 1, "锚点命中 %d 次（应为 1）" % c
if not CHECK_ONLY:
    open(P, "wb").write(data.replace(o, n))
print("OK  悬停判定认选中放大" + ("（仅检查）" if CHECK_ONLY else ""))
