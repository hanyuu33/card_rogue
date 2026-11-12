# -*- coding: utf-8 -*-
"""R623 补丁：① 同一张卡一回合只吃一次减费 ② 战斗内复制的复制品不继承商店附魔。

纪律：exact-replace + assert count == 1，按原文件的换行风格写回（不改 CRLF/LF）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def load(path):
    b = open(path, "rb").read()
    eol = "\r\n" if b"\r\n" in b else "\n"
    text = io.open(path, encoding="utf-8", newline="").read()
    return text, eol


def save(path, text):
    io.open(path, "w", encoding="utf-8", newline="").write(text)


def patch(path, old_lines, new_lines, tag):
    text, eol = load(path)
    old = eol.join(old_lines)
    new = eol.join(new_lines)
    n = text.count(old)
    if n != 1:
        print("FAIL %-28s count=%d" % (tag, n))
        sys.exit(1)
    save(path, text.replace(old, new))
    print("OK   %-28s" % tag)


GE = ROOT + "scripts/game_engine.gd"
RS = ROOT + "scripts/run_state.gd"

# ---------- 1. run_state.gd：strip_enchant ----------
patch(RS, [
    "static func _sync_mods_remove(index: int) -> void:",
], [
    "static func strip_enchant(c: CardData) -> bool:",
    "\t## R623：把**商店附魔**从一张已经烤过数值的卡上撤掉（战斗内复制专用）。",
    "\t##",
    "\t## 为什么需要它：`_apply_mod()` 把附魔烤进 cost / power / health / affix，烤完之后与",
    "\t## 「原生就长这样」的卡无法区分 —— 只有 `enchant`（附魔种类 id）还记得来源。",
    "\t## 战斗内复制（野兔 9032 / 复制术 9165）的复制品**不继承附魔**（店长口径），",
    "\t## 所以在复制之后先把附魔数值还原成原卡。",
    "\t##",
    "\t## ⚠️ 只认 `enchant`：空串 = 没吃过附魔（含老存档没记的情况）→ 原样返回，**一个字节都不动**。",
    "\t##    绝不能靠「猜数值」去减，那会把卡面原生的数值一起削掉。",
    "\t## ⚠️ 本局永久成长（`growth_power/health/damage`）**不是附魔**，这里不碰 —— 成长跟着卡种走，",
    "\t##    复制品照旧继承（与 R393 同口径）。",
    "\t## 返回 True = 真的剥掉了附魔。",
    "\tif c == null or c.enchant == \"\":",
    "\t\treturn false",
    "\tvar m := enchant_mod(c.enchant)",
    "\tif m.is_empty():",
    "\t\treturn false",
    "\tc.cost = maxi(0, c.cost - int(m.get(\"cost\", 0)))",
    "\tc.power = maxi(0, c.power - int(m.get(\"power\", 0)))",
    "\tc.health = maxi(0, c.health - int(m.get(\"health\", 0)))",
    "\tvar affix := str(m.get(\"affix\", \"\"))",
    "\tif affix != \"\":",
    "\t\tc.affixes.erase(affix)",
    "\tvar note := str(m.get(\"note\", \"\"))",
    "\tif note != \"\":",
    "\t\tvar tag := \"\\n【附魔】\" + note",
    "\t\tvar at := c.effect_text.find(tag)",
    "\t\tif at >= 0:",
    "\t\t\tc.effect_text = c.effect_text.substr(0, at) + c.effect_text.substr(at + tag.length())",
    "\tc.enchant = \"\"",
    "\tc.enchant_label = \"\"",
    "\treturn true",
    "",
    "",
    "static func _sync_mods_remove(index: int) -> void:",
], "run_state.strip_enchant")

# ---------- 2. game_engine.gd：_turn_discount_taken ----------
patch(GE, [
    "func _magic_core_discount(card: CardData, side:= SIDE_SELF) -> int:",
], [
    "func _turn_discount_taken(card: CardData) -> bool:",
    "\t## R623（店长口径）：**同一张卡一个回合只能吃一次减费**。",
    "\t## 判据 = 两张「回合级减费表」里这张卡是否已经有正数项：",
    "\t##   * `turn_card_discount` —— 魔像术 9079 / 影魔 8007 / 报废 8071 / 取牌类；",
    "\t##   * `hand_cost_turn`     —— 雪豹 8081 / 机械臂 6065 / 随心组装 9144 / 森林的朋友们 9183。",
    "\t## ⚠️ **负数 = 涨价**（不眠 9101 的「0 费卡本回合 +1」），不占减费额度 ——",
    "\t##    涨过价的卡本回合仍然可以被减一次。",
    "\t## ⚠️ 永久减费（`card_discount`：陨石术 9077 / 灵魂收割者）刻意不在判据里：",
    "\t##    那是「本场一直累加」的记账，与回合无关，也没有「一回合一次」的卡面语义。",
    "\t## ⚠️ 新入手 / 刚变化出来的卡（机械臂 / 森林的朋友们 / 随心组装 / 取牌）天然是新实例，",
    "\t##    判据必为 false —— 那几个写入点不需要再单独判一次。",
    "\tif card == null:",
    "\t\treturn false",
    "\tvar by_turn := int(state.turn_card_discount.get(card, 0))",
    "\tvar by_hand := int(state.hand_cost_turn.get(card, 0))",
    "\treturn by_turn > 0 or by_hand > 0",
    "",
    "",
    "func _magic_core_discount(card: CardData, side:= SIDE_SELF) -> int:",
], "engine._turn_discount_taken")

# ---------- 3. _discount_hand_skills ----------
patch(GE, [
    "\tvar zero := 0",
    "\tfor c: CardData in state.hand:",
    "\t\tif not c.is_spell():",
    "\t\t\tcontinue",
    "\t\tif n > 0:",
    "\t\t\tstate.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + n",
    "\t\tif not c.x_cost and cost_of(c, SIDE_SELF) == 0:",
    "\t\t\tzero += 1",
    "\tif hp_per > 0 and zero > 0:",
    "\t\tp.health += hp_per * zero",
    "\t_log(\"%s：手卡技能牌本回合 -%d 费；0 费技能卡 %d 张 → 生命 +%d（当前 %d）\" % [",
    "\t\t\tsource, n, zero, hp_per * zero, p.health])",
], [
    "\tvar zero := 0",
    "\tvar cut := 0",
    "\tfor c: CardData in state.hand:",
    "\t\tif not c.is_spell():",
    "\t\t\tcontinue",
    "\t\t# R623：同一张卡本回合只吃一次减费 —— 已经被雪豹 / 机械臂 / 另一张影魔减过的跳过，",
    "\t\t# 但下面「0 费技能卡 +生命」照常按**当前**账面费用判（卡面口径不变）。",
    "\t\tif n > 0 and not _turn_discount_taken(c):",
    "\t\t\tstate.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + n",
    "\t\t\tcut += 1",
    "\t\tif not c.x_cost and cost_of(c, SIDE_SELF) == 0:",
    "\t\t\tzero += 1",
    "\tif hp_per > 0 and zero > 0:",
    "\t\tp.health += hp_per * zero",
    "\t_log(\"%s：手卡技能牌本回合 -%d 费（本次 %d 张）；0 费技能卡 %d 张 → 生命 +%d（当前 %d）\" % [",
    "\t\t\tsource, n, cut, zero, hp_per * zero, p.health])",
], "engine._discount_hand_skills")

# ---------- 4. _discount_random_hand ----------
patch(GE, [
    "\tvar cand: Array[CardData] = []",
    "\tfor c: CardData in state.hand:",
    "\t\tif not c.x_cost and cost_of(c) > 0:",
    "\t\t\tcand.append(c)",
    "\tif cand.is_empty():",
    "\t\t_log(\"%s：手牌里没有可以减费的卡\" % tag)",
    "\t\treturn \"\"",
], [
    "\tvar cand: Array[CardData] = []",
    "\tfor c: CardData in state.hand:",
    "\t\t# R623：本回合已经减过费的那张不再进候选（同一张卡一回合只减一次）。",
    "\t\tif not c.x_cost and cost_of(c) > 0 and not _turn_discount_taken(c):",
    "\t\t\tcand.append(c)",
    "\tif cand.is_empty():",
    "\t\t_log(\"%s：手牌里没有可以减费的卡（每张本回合都已经减过）\" % tag)",
    "\t\treturn \"\"",
], "engine._discount_random_hand")

# ---------- 5. _spell_play_tick 魔像术 ----------
patch(GE, [
    "\t\tif c.id == GOLEM_SPELL_ID:",
    "\t\t\tstate.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + 1",
], [
    "\t\t# R623：魔像术本回合**只减一次**（第二张技能不再往上叠），与「同一张卡一回合一次」同口径。",
    "\t\tif c.id == GOLEM_SPELL_ID and not _turn_discount_taken(c):",
    "\t\t\tstate.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + 1",
], "engine.golem_once")

# ---------- 6. _spawn_self_clone 剥附魔 ----------
patch(GE, [
    "\tvar clone:= CardData.from_dict(card.to_dict())",
    "\tclone.traits = (card.traits as Array).duplicate()   # 切断与卡库的共享引用",
], [
    "\tvar clone:= CardData.from_dict(card.to_dict())",
    "\t# R623（店长口径）：复制品**不继承商店附魔** —— 已烤进 cost / power / health 的附魔数值、",
    "\t# 附魔带出来的 affix 与「【附魔】…」标注一起撤掉，回到原卡数值。",
    "\t# （本局永久成长 `card_growth` 不是附魔，照旧跟着卡种走，见 `RunState.card_with_mod()`。）",
    "\tRunState.strip_enchant(clone)",
    "\tclone.traits = (card.traits as Array).duplicate()   # 切断与卡库的共享引用",
], "engine._spawn_self_clone")

# ---------- 7. _duplicate_spell 剥附魔 ----------
patch(GE, [
    "\t\tvar copy:= CardData.from_dict(p.card.to_dict())",
    "\t\tcopy.traits = (p.card.traits as Array).duplicate()",
    "\t\tcopy.affixes = (p.card.affixes as Array).duplicate()",
], [
    "\t\tvar copy:= CardData.from_dict(p.card.to_dict())",
    "\t\tcopy.traits = (p.card.traits as Array).duplicate()",
    "\t\tcopy.affixes = (p.card.affixes as Array).duplicate()",
    "\t\t# R623：复制品不继承商店附魔。必须放在 affixes 复制**之后** ——",
    "\t\t# 否则上面那句会把附魔带出来的 affix（次元 / 保存）又抄回来。",
    "\t\tRunState.strip_enchant(copy)",
], "engine._duplicate_spell")

print("ALL DONE")
