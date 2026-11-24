# -*- coding: utf-8 -*-
"""R780 测试修正：⑥ 单目标技能口另开一局满血 80 起算（原来接着前面 20 血起算，
扣满 20 会归零并触发 _destroy_dead，断言基准写错了）。CRLF 原样。"""
import io
import sys

p = "E:/work/card_rogue/scripts/test_engine.gd"
NL = "\r\n"
s = io.open(p, encoding="utf-8", newline="").read()

old = NL.join([
    "\t# ⑥ 单目标技能那条落地口（`_op_deal_damage`）同样封顶",
    "",
    "\tengR780.turn_number += 1",
    "",
    "\tengR780._op_deal_damage(GameEngine.SIDE_SELF, 30, Vector2i(2, 1))",
    "",
    "\tcheck(pR780.health == 20 and pR780.turn_dmg_taken == 20,",
    "",
    "\t\t\t\"R780 单目标技能口（_op_deal_damage）同样封顶 20：40 → 20\")",
])

new = NL.join([
    "\t# ⑥ 单目标技能那条落地口（`_op_deal_damage`）同样封顶（另开一局，满血 80 起算）",
    "",
    "\tvar engR780c := _new_engine()",
    "",
    "\tengR780c.state.place(r780_card, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)",
    "",
    "\tvar pR780c: Placement = engR780c.state.unit_at(Vector2i(2, 1))",
    "",
    "\tengR780c.turn_number = 1",
    "",
    "\tengR780c._op_deal_damage(GameEngine.SIDE_SELF, 30, Vector2i(2, 1))",
    "",
    "\tcheck(pR780c.health == 60 and pR780c.turn_dmg_taken == 20,",
    "",
    "\t\t\t\"R780 单目标技能口（_op_deal_damage）同样封顶 20：80 → 60\")",
])

n = s.count(old)
if n != 1:
    sys.exit("锚点命中 %d 次（应为 1）" % n)

s = s.replace(old, new, 1)
io.open(p, "w", encoding="utf-8", newline="").write(s)

s2 = io.open(p, encoding="utf-8", newline="").read()
print("新段存在 =", "另开一局，满血 80 起算" in s2)
print("旧段残留 =", "同样封顶 20：40 → 20" in s2)
print("CRLF =", s2.count("\r\n"), "裸LF =", s2.count("\n") - s2.count("\r\n"))
