#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 引擎层 · 补丁 ②：卡牌包（填满手牌）/ 智慧药剂（抽 3）接进 use_tool。"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def patch(path, pairs):
    p = ROOT + path
    raw = io.open(p, encoding="utf-8", newline="").read()
    lf = raw.count("\n")
    crlf = raw.count("\r\n")
    if crlf > 0 and lf != crlf:
        print("FAIL %s 行尾混杂" % path)
        sys.exit(1)
    crlf_mode = crlf > 0
    s = raw.replace("\r\n", "\n")
    for old, new, note in pairs:
        n = s.count(old)
        if n != 1:
            print("FAIL %s 锚点命中 %d 次：%s" % (path, n, note))
            sys.exit(1)
        s = s.replace(old, new)
        print("OK  %s %s" % (path, note))
    if crlf_mode:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)


patch("scripts/game_engine.gd", [
    # ── 手牌已满时的早退（卡牌包用不了，别让它白吃掉一件消耗品）──
    ('	if t.pick_kind != "":\n'
     '		return false      # 选卡型：见 begin_tool_pick（这里返回 false 让界面知道没结算）\n'
     '	var healed := 0\n',
     '	if t.pick_kind != "":\n'
     '		return false      # 选卡型：见 begin_tool_pick（这里返回 false 让界面知道没结算）\n'
     '	# R796 卡牌包 7013：手牌**已经满**时用不了 —— 否则「填满手牌」等于什么都没做，\n'
     '	# 一件消耗品就这么蒸发了。与 `begin_tool_pick()` 的满手牌闸门同一口径：\n'
     '	# 提前挡在结算之前，界面照常提示原因，工具留在栏位里。\n'
     '	if t.fill_hand and state.hand_full():\n'
     '		_log("工具「%s」：手牌已满（%d 张），先打出一张再用" % [t.trap_name, FieldState.HAND_LIMIT])\n'
     '		return false\n'
     '	var healed := 0\n',
     "(卡牌包满手早退)"),

    # ── 结算：抽卡 / 填手牌 ──
    ('	var filled := 0\n'
     '	if t.fill_toolbar:\n',
     '	# R796 智慧药剂 7014：抽卡走 `_draw_many()`（所有「抽 n 张」的唯一口）——\n'
     '	# 手牌满时它会发 `hand_burn`、把牌丢进弃牌区，与战斗中一切抽卡同一口径。\n'
     '	var drawn := 0\n'
     '	if t.draw_cards > 0:\n'
     '		drawn = _draw_many(t.draw_cards)\n'
     '	# R796 卡牌包 7013：用随机卡填满手牌（唯一口 `_fill_hand_random()`）。\n'
     '	var hand_added := 0\n'
     '	if t.fill_hand:\n'
     '		hand_added = _fill_hand_random()\n'
     '	var filled := 0\n'
     '	if t.fill_toolbar:\n',
     "(抽卡 / 填手牌)"),

    ('	_log("使用工具：「%s」（回血 %d / 回费 %d / 盟友力量 +%d / 补工具 %d → HP %d/%d，费用 %d）" % [\n'
     '			t.trap_name, healed, t.energy, _wild_totem_atk, filled, state.hp_self,\n'
     '			state.max_hp_self, state.energy])\n',
     '	_log("使用工具：「%s」（回血 %d / 回费 %d / 盟友力量 +%d / 补工具 %d / 抽卡 %d / 填手牌 %d"\n'
     '			+ " → HP %d/%d，费用 %d）" % [\n'
     '			t.trap_name, healed, t.energy, _wild_totem_atk, filled, drawn, hand_added,\n'
     '			state.hp_self, state.max_hp_self, state.energy])\n',
     "(日志)"),

    ('	action.emit("tool_used", {"id": id, "name": t.trap_name, "healed": healed,\n'
     '			"energy": t.energy, "hp": state.hp_self, "max_hp": state.max_hp_self,\n'
     '			"filled": filled, "slots": RunState.traps.duplicate()})\n',
     '	action.emit("tool_used", {"id": id, "name": t.trap_name, "healed": healed,\n'
     '			"energy": t.energy, "hp": state.hp_self, "max_hp": state.max_hp_self,\n'
     '			"filled": filled, "drawn": drawn, "hand_added": hand_added,\n'
     '			"slots": RunState.traps.duplicate()})\n',
     "(事件载荷)"),

    # ── 填手牌的唯一口 ──
    ('func use_tool(id: int, slot := -1) -> bool:',
     'func _fill_hand_random() -> int:\n'
     '\t## R796 卡牌包 7013：「用随机卡牌填满你的手牌」的**唯一口**。返回实际进手牌的张数。\n'
     '\t## 池子 = 本职业奖励卡池（与神秘牌 7011 同一个口 `reward_pool_for()`）——\n'
     '\t## 用整副卡组当池子会把「你已经有的牌」再塞一遍，随机性全无。\n'
     '\t## 随机源走引擎 `rng`：同种子同结果、回放可复现（与新生 9148 / 随心组装同口径）。\n'
     '\t## ⚠️ 每张都过 `_new_own_card()`：手牌里永远是**独立副本**。实例级记账\n'
     '\t##    （`card_discount` / `turn_card_discount` / `hand_free` / `turn_free`）以 CardData\n'
     '\t##    对象为键，塞共享卡库实例会让「给这一张减费」变成「给所有同名卡减费」（R281 教训）。\n'
     '\t## ⚠️ 不设 `is_ephemeral`：包里开出来的是**真卡** —— 打掉进弃牌区、之后还能洗回牌库，\n'
     '\t##    与万能牌那种「回合结束消失的幻影」是两回事。\n'
     '\tvar pool: Array[CardData] = CardRepo.load_json().reward_pool_for(RunState.player_class)\n'
     '\tif pool.is_empty():\n'
     '\t\treturn 0\n'
     '\tvar added := 0\n'
     '\tvar guard := 0\n'
     '\twhile not state.hand_full() and guard < FieldState.HAND_LIMIT * 2:\n'
     '\t\tguard += 1\n'
     '\t\tvar c: CardData = _new_own_card(pool[rng.randi() % pool.size()])\n'
     '\t\tif _grant_to_hand(c, "卡牌包"):\n'
     '\t\t\tadded += 1\n'
     '\t_log("卡牌包：随机卡填入手牌 %d 张（现在 %d/%d）" % [\n'
     '\t\t\tadded, state.hand.size(), FieldState.HAND_LIMIT])\n'
     '\treturn added\n'
     '\n'
     '\n'
     'func use_tool(id: int, slot := -1) -> bool:',
     "(+_fill_hand_random)"),
])

print("DONE")
