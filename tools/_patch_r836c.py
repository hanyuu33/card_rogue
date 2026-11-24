# -*- coding: utf-8 -*-
"""R836c：淡出推迟到 92%，让「卡住抖两下」在完全淡出前看得见。"""
ROOT = "E:/work/card_rogue/"
BS = "scripts/battle_scene.gd"
b = open(ROOT + BS, "rb").read()

old = (
    "\tvar a := 1.0\r\n"
    "\tif t > 0.86:\r\n"
    "\t\ta = maxf(0.0, 1.0 - (t - 0.86) / 0.14)\r\n"
).encode("utf-8")
new = (
    "\tvar a := 1.0\r\n"
    "\t# 淡出压到 92% 才开始：抖动那两下（74%~100%）得在还看得清的时候发生\r\n"
    "\tif t > 0.92:\r\n"
    "\t\ta = maxf(0.0, 1.0 - (t - 0.92) / 0.08)\r\n"
).encode("utf-8")
assert b.count(old) == 1, b.count(old)
b = b.replace(old, new)
open(ROOT + BS, "wb").write(b)
print("淡出推迟到 92%")
