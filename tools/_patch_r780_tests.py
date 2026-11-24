# -*- coding: utf-8 -*-
"""R780：给赫尔墨斯「每回合最多受到 20 点伤害」补测试断言（CRLF 原样）。

插在 R161（行动力成长）段末、R162 段前。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"
NL = "\r\n"
p = ROOT + "scripts/test_engine.gd"

s = io.open(p, encoding="utf-8", newline="").read()
anchor = "\t# ---- R162：阿斯克勒庇厄斯 + 护甲积攒 ----"
if s.count(anchor) != 1:
    sys.exit("锚点命中 %d 次（应为 1）" % s.count(anchor))

block = NL.join([
    "\t# ---- R780：赫尔墨斯「每回合最多受到 20 点伤害」----",
    "",
    "\tvar r780_card := repo.get_card(9140)",
    "",
    "\tcheck(r780_card != null and r780_card.effect_text.contains(\"每回合最多受到 20 点伤害\"),",
    "",
    "\t\t\t\"R780 赫尔墨斯卡面：写明「每回合最多受到 20 点伤害」\")",
    "",
    "\tcheck(GameEngine.HERMES_ID == 9140 and GameEngine.HERMES_DMG_CAP == 20,",
    "",
    "\t\t\t\"R780 常量：HERMES_ID = 9140 / HERMES_DMG_CAP = 20\")",
    "",
    "",
    "\tvar engR780 := _new_engine()",
    "",
    "\tengR780.state.place(r780_card, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)",
    "",
    "\tvar pR780: Placement = engR780.state.unit_at(Vector2i(2, 1))",
    "",
    "\tengR780.turn_number = 1",
    "",
    "\tcheck(pR780.health == 80 and pR780.turn_dmg_taken == 0 and pR780.turn_dmg_key == -1,",
    "",
    "\t\t\t\"R780 赫尔墨斯上场：80 血，本回合累计 0、key 未记账\")",
    "",
    "\t# ① 额度内照常全额",
    "",
    "\tvar r780_d1: int = engR780._hit_unit(pR780, 12, \"技能\", false)",
    "",
    "\tcheck(r780_d1 == 12 and pR780.health == 68 and pR780.turn_dmg_taken == 12,",
    "",
    "\t\t\t\"R780 第 1 下 12 点：全额落地（80 → 68），本回合累计 12\")",
    "",
    "\t# ② 单次远超剩余额度 → 只吃剩下的 8 点",
    "",
    "\tvar r780_d2: int = engR780._hit_unit(pR780, 30, \"技能\", false)",
    "",
    "\tcheck(r780_d2 == 8 and pR780.health == 60 and pR780.turn_dmg_taken == 20,",
    "",
    "\t\t\t\"R780 第 2 下 30 点：只吃剩余 8 点（封顶 20），68 → 60\")",
    "",
    "\t# ③ 额度打满 → 全免",
    "",
    "\tvar r780_d3: int = engR780._hit_unit(pR780, 25, \"技能\", false)",
    "",
    "\tcheck(r780_d3 == 0 and pR780.health == 60,",
    "",
    "\t\t\t\"R780 第 3 下：本回合已满 20 → 全免，血量不变\")",
    "",
    "\t# ④ 换回合（turn_number +1 = 下一个我方回合开始）→ 额度归零，单次最多 20",
    "",
    "\tengR780.turn_number += 1",
    "",
    "\tvar r780_d4: int = engR780._hit_unit(pR780, 25, \"技能\", false)",
    "",
    "\tcheck(r780_d4 == 20 and pR780.health == 40 and pR780.turn_dmg_taken == 20,",
    "",
    "\t\t\t\"R780 换回合后额度归零：单次 25 点封顶到 20，60 → 40\")",
    "",
    "\t# ⑤ 预览镜像：R384 纪律 —— 预览值必须等于实际扣血值",
    "",
    "\tengR780.turn_number += 1",
    "",
    "\tvar r780_pv: Dictionary = engR780.preview_hit_damage(pR780, 30, false)",
    "",
    "\tvar r780_d5: int = engR780._hit_unit(pR780, 30, \"技能\", false)",
    "",
    "\tcheck(int(r780_pv[\"dmg\"]) == 20 and r780_d5 == int(r780_pv[\"dmg\"]),",
    "",
    "\t\t\t\"R780 预览：满额度 30 点报 20，与实际扣血一致\")",
    "",
    "\tvar r780_pv2: Dictionary = engR780.preview_hit_damage(pR780, 30, false)",
    "",
    "\tcheck(int(r780_pv2[\"dmg\"]) == 0,",
    "",
    "\t\t\t\"R780 预览：本回合额度用满后报 0\")",
    "",
    "\t# ⑥ 单目标技能那条落地口（`_op_deal_damage`）同样封顶",
    "",
    "\tengR780.turn_number += 1",
    "",
    "\tengR780._op_deal_damage(GameEngine.SIDE_SELF, 30, Vector2i(2, 1))",
    "",
    "\tcheck(pR780.health == 20 and pR780.turn_dmg_taken == 20,",
    "",
    "\t\t\t\"R780 单目标技能口（_op_deal_damage）同样封顶 20：40 → 20\")",
    "",
    "\t# ⑦ 对照：不是赫尔墨斯的单位不吃这条上限",
    "",
    "\tvar r780_other := repo.get_card(9141)",
    "",
    "\tvar engR780b := _new_engine()",
    "",
    "\tengR780b.state.place(r780_other, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)",
    "",
    "\tvar pR780b: Placement = engR780b.state.unit_at(Vector2i(2, 1))",
    "",
    "\tengR780b.turn_number = 1",
    "",
    "\tvar r780_o: int = engR780b._hit_unit(pR780b, 30, \"技能\", false)",
    "",
    "\tcheck(r780_o == 30 and pR780b.turn_dmg_taken == 0,",
    "",
    "\t\t\t\"R780 对照：阿斯克勒庇厄斯单次 30 点不封顶（上限只属于 9140）\")",
    "",
    "",
    "",
])

s = s.replace(anchor, block + anchor, 1)
io.open(p, "w", encoding="utf-8", newline="").write(s)

# 回读
s2 = io.open(p, encoding="utf-8", newline="").read()
print("段首存在 =", "R780：赫尔墨斯「每回合最多受到 20 点伤害」" in s2)
print("check 条数 =", s2.count("R780 "))
print("CRLF =", s2.count("\r\n"), "裸LF =", s2.count("\n") - s2.count("\r\n"))
