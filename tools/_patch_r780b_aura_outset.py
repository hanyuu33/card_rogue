# -*- coding: utf-8 -*-
"""R780b 第二步：六边形要**离开卡框**，否则会被读成「边框加粗了」。

实拍结论：`+5 / +11 px` 贴着卡边时，亮金和卡牌自带的金边框连成一片 ——
玩家看到的是「这张卡描边厚」，不是「这张卡被罩住了」。把整圈推到 `+12 / +20`，
中间留出可见缝隙（缝隙里是水面），六边形才成立为「另一个物体」。
"""
import io
import sys

P = "E:/work/card_rogue/scripts/battle_scene.gd"
s = io.open(P, encoding="utf-8", newline="").read()

reps = [
    ("w * 0.5 + 5.0 + float(k) * 6.0 + dc_pulse * 1.6", "w * 0.5 + 12.0 + float(k) * 8.0 + dc_pulse * 1.8"),
    ("h * 0.5 + 5.0 + float(k) * 6.0 + dc_pulse * 1.6", "h * 0.5 + 12.0 + float(k) * 8.0 + dc_pulse * 1.8"),
    ("cos(a2) * (w * 0.5 + 5.0 + dc_pulse * 1.6)", "cos(a2) * (w * 0.5 + 12.0 + dc_pulse * 1.8)"),
    ("sin(a2) * (h * 0.5 + 5.0 + dc_pulse * 1.6)", "sin(a2) * (h * 0.5 + 12.0 + dc_pulse * 1.8)"),
]
for o, n in reps:
    c = s.count(o)
    if c != 1:
        sys.exit("锚点计数 %d（应为 1）：%s" % (c, o))
    s = s.replace(o, n, 1)

for chk in reps:
    if chk[0] in s:
        sys.exit("回读失败，旧值仍在：%s" % chk[0])

io.open(P, "w", encoding="utf-8", newline="").write(s)
print("AURA_OUTSET ok  count12=%d" % s.count("+ 12.0 +"))
