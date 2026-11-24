# -*- coding: utf-8 -*-
"""R761 补丁 12：scripts/test_reward.gd 的卡牌总数断言 323 → 325。"""
import sys

P = "scripts/test_reward.gd"
raw = open(P, "rb").read()
if raw.count(b"\n") != raw.count(b"\r\n"):
    nl = b"\n"
else:
    nl = b"\r\n"
t = raw.decode("utf-8")

pairs = [
    ("check(all.size() == 323, \"卡牌库 323 张（R756 +3：",
     "check(all.size() == 325, \"卡牌库 325 张（R761 +2：杜鹃 9263 / 招募 9264（吟游诗人 · "
     "隐藏职业的初始卡，rarity 3 不进奖励池）；R756 +3："),
]
for old, new in pairs:
    if t.count(old) != 1:
        print("FAIL 锚点命中 %d 次：%r" % (t.count(old), old[:80]))
        sys.exit(1)
    t = t.replace(old, new, 1)

open(P, "wb").write(t.encode("utf-8"))
print("test_reward.gd OK")
