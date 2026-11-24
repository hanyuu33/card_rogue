# -*- coding: utf-8 -*-
"""临时调试：给干净版战斗场景的 aura 调用点插一条一次性打印，定位「环没画出来」。"""
import io
import sys

P = "E:/work/card_rogue/tools/_tmp_r780b_battle_clean.gd"
s = io.open(P, encoding="utf-8", newline="").read()
NL = "\r\n"

old = NL.join([
    "\tif engine.damage_cap_left(p) == 0:",
    "\t\t# R780b 赫尔墨斯 9140 / 量产型赫尔墨斯 9188：本回合 20 点伤害额度已经吃满，",
])
new = NL.join([
    "\tif not Engine.has_meta(\"r780b_dbg\"):",
    "\t\tEngine.set_meta(\"r780b_dbg\", true)",
    "\t\tprint(\"[DBG] left=%d taken=%d key=%d turn=%d w=%.1f h=%.1f\" % ["
    "engine.damage_cap_left(p), p.turn_dmg_taken, p.turn_dmg_key, engine.turn_number, w, h])",
    "\tif engine.damage_cap_left(p) == 0:",
    "\t\t# R780b 赫尔墨斯 9140 / 量产型赫尔墨斯 9188：本回合 20 点伤害额度已经吃满，",
])
if s.count(old) != 1:
    sys.exit("锚点计数 %d" % s.count(old))
io.open(P, "w", encoding="utf-8", newline="").write(s.replace(old, new, 1))
print("DBG_INJECTED")
