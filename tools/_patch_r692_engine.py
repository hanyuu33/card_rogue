# -*- coding: utf-8 -*-
"""R692 引擎补丁：飓风咆哮每次触发×X / 鸭蛋改回合开始孵化 / 鸭妈妈召唤小鸭 / 小鸭减费。

用法：python tools/_patch_r692_engine.py [--write]
"""
import sys

P = "E:/work/card_rogue/scripts/game_engine.gd"
WRITE = "--write" in sys.argv

raw = open(P, "rb").read().decode("utf-8")
assert raw.count("\r\n") == raw.count("\n"), "game_engine.gd 不是纯 CRLF"
out = raw


def rep(old, new, tag, cnt=1):
    global out
    c = out.count(old)
    assert c == cnt, "[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, cnt)
    out = out.replace(old, new)


# ── ① 常量 ──
rep(
    'const PET_DUCK_TRAIT:= "宠物鸭"\r\n',
    'const PET_DUCK_TRAIT:= "宠物鸭"\r\n'
    '# R692：鸭妈妈 9250（森林精魄 · 4 费稀有盟友）→ 使用时在**两侧**各召唤一只小鸭 9251。\r\n'
    '# 小鸭是 token（rarity 5，不进奖励池），入场时使手卡里随机一张效果卡费用 -1。\r\n'
    'const DUCK_MOTHER_ID:= 9250\r\n'
    'const DUCKLING_ID:= 9251\r\n',
    "常量",
)

# ── ② 飓风咆哮：去掉「每回合前 X 次」门槛，改为每次使用都结算 X 下 ──
rep(
    "# 「每回合第 X 次」的 X = 效果区张数 → 用计数记录本回合已触发几次（回合开始归零）\r\n"
    "var _roar_fires:= 0\r\n"
    "var _space_fires:= 0\r\n",
    "# 「每回合第 X 次」的 X = 效果区张数 → 用计数记录本回合已触发几次（回合开始归零）。\r\n"
    "# R692：「飓风咆哮」改成**每次**使用效果卡都触发（不再数次数），只剩和风守护还用这个计数。\r\n"
    "var _space_fires:= 0\r\n",
    "计数变量",
)
rep("\t\t_roar_fires = 0\r\n", "", "计数归零")

rep(
    '\t# 「每回合第 X 次」：X = 效果区里该类卡的张数（单张时 X=1 → 就是原来的「每回合首次」）。\r\n'
    '\tif not skip_roar:\r\n'
    '\t\tvar roar_n:= _trait_copies(state.effects, AETHER_ROAR_TRAIT)\r\n'
    '\t\tif roar_n > 0 and _roar_fires < roar_n:\r\n'
    '\t\t\t_roar_fires += 1\r\n'
    '\t\t\tvar roar_c:= _first_with_trait(state.effects, AETHER_ROAR_TRAIT)\r\n'
    '\t\t\tif roar_c != null:\r\n'
    '\t\t\t\t_aether_roar(roar_c)\r\n',
    '\t# R692（店长口径「改为每次使用效果卡，叠加改为造成 X 次」）：\r\n'
    '\t#   ① 不再有「每回合前 X 次」的门槛 —— 本回合**每一次**使用效果卡都触发；\r\n'
    '\t#   ② 叠加改成**打 X 下**（X = 效果区里本卡的张数），每一下各自重挑目标。\r\n'
    '\tif not skip_roar:\r\n'
    '\t\tvar roar_n:= _trait_copies(state.effects, AETHER_ROAR_TRAIT)\r\n'
    '\t\tif roar_n > 0:\r\n'
    '\t\t\tvar roar_c:= _first_with_trait(state.effects, AETHER_ROAR_TRAIT)\r\n'
    '\t\t\tif roar_c != null:\r\n'
    '\t\t\t\tfor _i in roar_n:\r\n'
    '\t\t\t\t\t_aether_roar(roar_c)\r\n'
    '\t# 和风守护仍是「每回合前 X 次」（本轮没动它）。\r\n',
    "飓风咆哮",
)

# ── ③ 鸭蛋孵化：回合结束 → 我方回合开始 ──
rep(
    "\t\t# R340 生蛋鸭：存活到回合结束的鸭蛋 → 原地孵成宠物鸭（与罐子同一段收尾，先于弃手牌）\r\n"
    "\t\t_egg_hatch_tick()\r\n",
    "",
    "移除回合结束孵化",
)
rep(
    "\t\t_spring_tick()          # R307 泉水：后排单位每回合回 4\r\n",
    "\t\t# R692（店长口径「鸭蛋改为（我方）回合开始时若存活」）：孵化从**回合结束**搬到\r\n"
    "\t\t# **我方回合开始**。排在 `state.reset_units()` 之前 → 刚孵出的宠物鸭这一回合就能行动。\r\n"
    "\t\t_egg_hatch_tick()\r\n"
    "\t\t_spring_tick()          # R307 泉水：后排单位每回合回 4\r\n",
    "插入回合开始孵化",
)
rep(
    "\t## 生蛋鸭（6018）/ 鸭蛋（9022，R340）：**我方回合结束时**仍存活的鸭蛋\r\n",
    "\t## 生蛋鸭（6018）/ 鸭蛋（9022，R340；R692 改为**我方回合开始时**）：仍存活的鸭蛋\r\n",
    "孵化注释",
)

# ── ④ 小鸭入场减费钩子 ──
rep(
    '\tif p.card.kind != "盟友":\r\n'
    '\t\treturn\r\n'
    '\t_wind_force_tick(side, "%s 登场" % p.card.card_name)\r\n',
    '\tif p.card.kind != "盟友":\r\n'
    '\t\treturn\r\n'
    '\tif p.card.id == DUCKLING_ID:\r\n'
    '\t\t_duckling_discount(p)   # R692：小鸭入场 → 手卡随机一张效果卡 -1\r\n'
    '\t_wind_force_tick(side, "%s 登场" % p.card.card_name)\r\n',
    "小鸭钩子",
)

# ── ⑤ 水元素之后插入鸭妈妈 / 小鸭的实现 ──
rep(
    '\taction.emit("water_element", {"card": vortex})\r\n'
    '\r\n'
    '\r\n'
    'func _owl_fetch() -> void :\r\n',
    '\taction.emit("water_element", {"card": vortex})\r\n'
    '\r\n'
    '\r\n'
    'func _duck_mother_summon(p: Placement) -> void :\r\n'
    '\t## R692：鸭妈妈 9250「使用时，在这张卡两边各召唤一只「小鸭」（如果可能）」。\r\n'
    '\t## * 「两边」= **同一行**左右相邻格（列 -1 / +1）；越界 / 已被占 / 行归属不合法\r\n'
    '\t##   的那一侧**直接跳过**，不往别处替补（卡面写的是「如果可能」）。\r\n'
    '\t## * 落点仍过 `_can_hold()`（空格 + `unit_slot_allowed` 的 HP 行硬禁区）。\r\n'
    '\t## * 副本走 `from_dict` + `traits.duplicate()`：卡库实例共享，场上被改造会跨局泄漏。\r\n'
    '\t## * `_on_ally_entered()` 照常调用 —— 小鸭的减费就挂在那条钩子上。\r\n'
    '\tif p == null:\r\n'
    '\t\treturn\r\n'
    '\tvar cell:= _cell_of(p)\r\n'
    '\tif cell == Vector2i(-1, -1):\r\n'
    '\t\treturn\r\n'
    '\tvar base: CardData = CardRepo.load_json().get_card(DUCKLING_ID)\r\n'
    '\tif base == null:\r\n'
    '\t\t_log("鸭妈妈：卡牌库里没有「小鸭」（%d）" % DUCKLING_ID)\r\n'
    '\t\treturn\r\n'
    '\tvar made:= 0\r\n'
    '\tfor dc: int in [-1, 1]:\r\n'
    '\t\tvar spot:= Vector2i(cell.x, cell.y + dc)\r\n'
    '\t\tif not _can_hold(spot, p.owner):\r\n'
    '\t\t\tcontinue\r\n'
    '\t\tvar duck: CardData = CardData.from_dict(base.to_dict())\r\n'
    '\t\tduck.traits = (duck.traits as Array).duplicate()\r\n'
    '\t\tvar born:= state.place(duck, spot, p.owner)\r\n'
    '\t\tmade += 1\r\n'
    '\t\t_log("鸭妈妈：在 %s 召唤「%s」（%d 攻 / %d 血）" % [\r\n'
    '\t\t\t\tstr(spot), duck.card_name, duck.power, duck.health])\r\n'
    '\t\taction.emit("place", {"cell": spot, "card": duck, "side": p.owner,\r\n'
    '\t\t\t\t"summon": true, "from": cell})\r\n'
    '\t\t_on_ally_entered(born, p.owner)\r\n'
    '\t_log("鸭妈妈：两侧共召唤 %d 只小鸭" % made)\r\n'
    '\taction.emit("duck_mother", {"cell": cell, "count": made})\r\n'
    '\r\n'
    '\r\n'
    'func _duckling_discount(p: Placement) -> void :\r\n'
    '\t## R692：小鸭 9251「入场时，手卡随机一张效果卡 -1 费」。\r\n'
    '\t## * 候选 = `state.hand` 里的效果卡；`state.hand` 顺序稳定 → 同种子回放可复现。\r\n'
    '\t## * 减费走 `state.hand_cost_delta`（唯一口径）：**只在手卡内有效**，\r\n'
    '\t##   打出 / 弃掉即恢复原价（与小精灵 9074 / 雪豹同一套）。\r\n'
    '\tif p == null or p.owner != SIDE_SELF:\r\n'
    '\t\treturn\r\n'
    '\tvar cand: Array[CardData] = []\r\n'
    '\tfor c: CardData in state.hand:\r\n'
    '\t\tif c.is_effect():\r\n'
    '\t\t\tcand.append(c)\r\n'
    '\tif cand.is_empty():\r\n'
    '\t\t_log("小鸭：手卡没有效果卡 → 落空")\r\n'
    '\t\taction.emit("duckling", {"card": null, "amount": 0})\r\n'
    '\t\treturn\r\n'
    '\tvar pick: CardData = cand[rng.randi() % cand.size()]\r\n'
    '\tstate.hand_cost_delta[pick] = int(state.hand_cost_delta.get(pick, 0)) + 1\r\n'
    '\t_log("小鸭：手卡「%s」费用 -1（手卡内有效，打出 / 弃掉恢复原价）" % pick.card_name)\r\n'
    '\taction.emit("duckling", {"card": pick, "amount": 1})\r\n'
    '\r\n'
    '\r\n'
    'func _owl_fetch() -> void :\r\n',
    "鸭妈妈实现",
)

# ── ⑥ 打出鸭妈妈时触发 ──
rep(
    '\tif card.id == AETHER_DEMON_ID:\r\n'
    '\t\t_water_element_fetch(p)\r\n',
    '\tif card.id == AETHER_DEMON_ID:\r\n'
    '\t\t_water_element_fetch(p)\r\n'
    '\r\n'
    '\tif card.id == DUCK_MOTHER_ID:\r\n'
    '\t\t_duck_mother_summon(p)\r\n',
    "鸭妈妈触发",
)

b = out.encode("utf-8")
assert b.count(b"\r\n") == out.count("\n"), "写出后不是纯 CRLF"
print("替换完成，行数 %d → %d" % (raw.count("\n"), out.count("\n")))
if WRITE:
    open(P, "wb").write(b)
    print("WROTE")
else:
    print("DRY-RUN")
