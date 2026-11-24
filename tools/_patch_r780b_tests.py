# -*- coding: utf-8 -*-
"""R780b 测试：9188 同吃上限 + damage_cap_left 界面判据 + 名单边界。"""
import io
import sys

ROOT = "E:/work/card_rogue/"
NL = "\r\n"
p = ROOT + "scripts/test_engine.gd"
s = io.open(p, encoding="utf-8", newline="").read()

OLD = NL.join([
    '\t\t\t"R780 对照：阿斯克勒庇厄斯单次 30 点不封顶（上限只属于 9140）")',
])

NEW = NL.join([
    '\t\t\t"R780 对照：阿斯克勒庇厄斯单次 30 点不封顶（它不在上限名单里）")',
    '',
    '\t# ---- R780b：量产型赫尔墨斯 9188 同吃「每回合最多受到 20 点伤害」+ 界面判据 ----',
    '',
    '\tcheck(GameEngine.is_damage_capped(9140) and GameEngine.is_damage_capped(9188),',
    '\t\t\t"R780b 上限名单：9140 赫尔墨斯与 9188 量产型赫尔墨斯都在内")',
    '',
    '\tcheck(not GameEngine.is_damage_capped(9141) and not GameEngine.is_damage_capped(9189),',
    '\t\t\t"R780b 上限名单边界：9141 阿斯克勒庇厄斯 / 9189 独行 不在内")',
    '',
    '\tvar r780b_card := repo.get_card(9188)',
    '',
    '\tcheck(r780b_card != null and r780b_card.card_name == "量产型赫尔墨斯"',
    '\t\t\tand r780b_card.effect_text.contains("每回合最多受到 20 点伤害"),',
    '\t\t\t"R780b 9188 卡面：写明「每回合最多受到 20 点伤害」")',
    '',
    '\tvar engR780d := _new_engine()',
    '',
    '\tengR780d.state.place(r780b_card, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)',
    '',
    '\tvar pR780d: Placement = engR780d.state.unit_at(Vector2i(2, 1))',
    '',
    '\tengR780d.turn_number = 1',
    '',
    '\t# ① 界面判据：开局还剩满额度 → 力场环不亮（亮灯判据是 == 0，不是 > 0）',
    '',
    '\tcheck(engR780d.damage_cap_left(pR780d) == 20,',
    '\t\t\t"R780b 9188 开局：damage_cap_left = 20（大于 0 就不画环）")',
    '',
    '\t# ② 一次 30 点只吃 20',
    '',
    '\tvar r780b_d1: int = engR780d._hit_unit(pR780d, 30, "技能", false)',
    '',
    '\tcheck(r780b_d1 == 20 and pR780d.health == 35,',
    '\t\t\t"R780b 9188 单次 30 点封顶到 20（55 → 35）")',
    '',
    '\t# ③ 额度吃满 → 判据归 0，卡面力场环 + 「免伤」图标常驻',
    '',
    '\tcheck(engR780d.damage_cap_left(pR780d) == 0,',
    '\t\t\t"R780b 9188 额度吃满：damage_cap_left = 0 → 力场环与免伤图标常驻")',
    '',
    '\t# ④ 满额度后再打：一点也进不去（这一下必须发出 damage_capped 让界面有反馈）',
    '',
    '\tvar r780b_hits: Array = []',
    '',
    '\tengR780d.action.connect(func(kind: String, d: Dictionary):',
    '\t\t\tif kind == "damage_capped":',
    '\t\t\t\tr780b_hits.append(int(d.get("blocked", 0))))',
    '',
    '\tvar r780b_d2: int = engR780d._hit_unit(pR780d, 30, "技能", false)',
    '',
    '\tcheck(r780b_d2 == 0 and pR780d.health == 35,',
    '\t\t\t"R780b 9188 满额度后再挨 30 点：全免、血量不变")',
    '',
    '\tcheck(r780b_hits == [30],',
    '\t\t\t"R780b 全免时发出 damage_capped(blocked=30) → 界面才有「免伤 30」飘字")',
    '',
    '\t# ⑤ 换回合：额度回到 20（力场环随之消失）',
    '',
    '\tengR780d.turn_number += 1',
    '',
    '\tcheck(engR780d.damage_cap_left(pR780d) == 20,',
    '\t\t\t"R780b 换回合：额度回到 20，力场环跟着灭")',
    '',
    '\t# ⑥ 部分额度：读数真的按剩余量走（界面不带环，但「还能吃 8 点」是对的）',
    '',
    '\tvar r780b_d3: int = engR780d._hit_unit(pR780d, 12, "技能", false)',
    '',
    '\tcheck(r780b_d3 == 12 and engR780d.damage_cap_left(pR780d) == 8,',
    '\t\t\t"R780b 9188 吃了 12 点后还剩 8 点额度")',
    '',
    '\t# ⑦ 对照：名单外的单位返回 -1（不吃上限，也不画力场）',
    '',
    '\tcheck(engR780b.damage_cap_left(pR780b) == -1,',
    '\t\t\t"R780b 对照：名单外单位 damage_cap_left 返回 -1（不画力场）")',
    '',
])

if s.count(OLD) != 1:
    sys.exit("锚点计数 %d" % s.count(OLD))
s = s.replace(OLD, NEW, 1)
io.open(p, "w", encoding="utf-8", newline="").write(s)

# 回读校验
s2 = io.open(p, encoding="utf-8", newline="").read()
for needle in ("R780b 上限名单", "damage_cap_left(pR780d) == 0",
               "r780b_hits == [30]", "damage_cap_left(pR780b) == -1"):
    if s2.count(needle) < 1:
        sys.exit("回读缺 %r" % needle)
b = io.open(p, "rb").read()
print("TEST_OK CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
