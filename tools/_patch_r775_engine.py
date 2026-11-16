# -*- coding: utf-8 -*-
"""R775 补丁：game_engine.gd —— _assemble_execute 加 turn_start_effects 段；
_assemble_apply_fx 加 bonus_hp_per_upgrade / fetch_skill / self_destruct 三个动作分支（保持 CRLF）。"""
import io

P = 'scripts/game_engine.gd'
with io.open(P, 'r', encoding='utf-8', newline='') as f:
    s = f.read()
assert s.count('\r\n') > 0, 'game_engine.gd 应该是 CRLF'

edits = []

# 1) _assemble_execute：声明 ts 段 + if 条件纳入 has_ts
edits.append((
    '\tvar has_main := key == trigger and not _assemble_active.has(execution_key)\r\n'
    '\tif not has_enter and not has_main:\r\n',
    '\tvar has_main := key == trigger and not _assemble_active.has(execution_key)\r\n'
    '\t# R775：上半可带**独立回合开始段** turn_start_effects（幽灵「自己回合开始时自毁」）。\r\n'
    '\t# 与入场段同源：不挂主扳机，只在 turn_start 兑现一次（自毁后单位离场，天然不重复）。\r\n'
    '\tvar ts_key := str(p.get_instance_id()) + ":turn_start_effects"\r\n'
    '\tvar ts_q: Array = (p.card.assemble.get("turn_start_effects", []) as Array).duplicate(true)\r\n'
    '\tvar has_ts := trigger == "turn_start" and not ts_q.is_empty() and not _assemble_active.has(ts_key)\r\n'
    '\tif not has_enter and not has_main and not has_ts:\r\n'))

# 2) fx_queue 构建：has_enter 之后追加 has_ts 段
edits.append((
    '\tif has_enter:\r\n'
    '\t\t# 入场段是一次性的：enter_key 不随结算链 erase，同一实例只兑现一次。\r\n'
    '\t\t_assemble_active[enter_key] = true\r\n'
    '\t\tfx_queue.append_array(enter_q)\r\n'
    '\tif has_main:\r\n',
    '\tif has_enter:\r\n'
    '\t\t# 入场段是一次性的：enter_key 不随结算链 erase，同一实例只兑现一次。\r\n'
    '\t\t_assemble_active[enter_key] = true\r\n'
    '\t\tfx_queue.append_array(enter_q)\r\n'
    '\tif has_ts:\r\n'
    '\t\t_assemble_active[ts_key] = true\r\n'
    '\t\tfx_queue.append_array(ts_q)\r\n'
    '\tif has_main:\r\n'))

# 3) upgrade 动作之后加 bonus_hp_per_upgrade
edits.append((
    '\t\t"upgrade":\r\n'
    '\t\t\tp.card = _renew_field_card(p)\r\n'
    '\t\t\tp.card.traits = (p.card.traits as Array).duplicate()\r\n'
    '\t\t\tp.upgrade_atk += value\r\n'
    '\t\t\tp.upgrade_hp += value\r\n'
    '\t\t\t_add_upgrade_stack(p)\r\n'
    '\t\t\tp.card.health += value\r\n'
    '\t\t\tp.health += value\r\n'
    '\t\t"range":\r\n',
    '\t\t"upgrade":\r\n'
    '\t\t\tp.card = _renew_field_card(p)\r\n'
    '\t\t\tp.card.traits = (p.card.traits as Array).duplicate()\r\n'
    '\t\t\tp.upgrade_atk += value\r\n'
    '\t\t\tp.upgrade_hp += value\r\n'
    '\t\t\t_add_upgrade_stack(p)\r\n'
    '\t\t\tp.card.health += value\r\n'
    '\t\t\tp.health += value\r\n'
    '\t\t"bonus_hp_per_upgrade":\r\n'
    '\t\t\t# R775：堡垒「每拥有一层改造 +N 生命」—— 只在「被改造」扳机下额外加生命，\r\n'
    '\t\t\t# 不加力量、不加层数（否则与 `upgrade` 动作重复计层）。\r\n'
    '\t\t\tp.card = _renew_field_card(p)\r\n'
    '\t\t\tp.upgrade_hp += value\r\n'
    '\t\t\tp.card.health += value\r\n'
    '\t\t\tp.health += value\r\n'
    '\t\t"range":\r\n'))

# 4) draw_random_skill 之后加 fetch_skill
edits.append((
    '\t\t"draw_random_skill":\r\n'
    '\t\t\t# R570：赤狐 9034「从卡组随机抽一张技能牌，该卡本回合费用 -N」\r\n'
    '\t\t\t# （共用 `_fetch_skill_card`，牌库当场少一张、减费只挂那一张）。\r\n'
    '\t\t\t_fetch_skill_card("组合", value)\r\n'
    '\t\t"hand_cost_raise":\r\n',
    '\t\t"draw_random_skill":\r\n'
    '\t\t\t# R570：赤狐 9034「从卡组随机抽一张技能牌，该卡本回合费用 -N」\r\n'
    '\t\t\t# （共用 `_fetch_skill_card`，牌库当场少一张、减费只挂那一张）。\r\n'
    '\t\t\t_fetch_skill_card("组合", value)\r\n'
    '\t\t"fetch_skill":\r\n'
    '\t\t\t# R775：影子猫 / 幽灵「从卡组随机技能卡入手」（无减费）。\r\n'
    '\t\t\t# if_third = 影子猫条件「本回合第 3 张（含本卡）」，判据与母卡 _shadow_cat_trigger 同源。\r\n'
    '\t\t\tif p.owner != SIDE_SELF:\r\n'
    '\t\t\t\t_assemble_opponent_draw(1)\r\n'
    '\t\t\t\treturn\r\n'
    '\t\t\tif fx.get("if_third", false) and state.self_card_plays + 1 < SHADOW_CAT_NEED:\r\n'
    '\t\t\t\t_log("组合：影子猫条件不满足（本回合第 %d 张，需 %d 张）" % [state.self_card_plays + 1, SHADOW_CAT_NEED])\r\n'
    '\t\t\t\treturn\r\n'
    '\t\t\t_fetch_skill_from_deck(0)\r\n'
    '\t\t"hand_cost_raise":\r\n'))

# 5) damage 之后加 self_destruct
edits.append((
    '\t\t\tfor target in targets:\r\n'
    '\t\t\t\tif state.board.has(target):\r\n'
    '\t\t\t\t\t_hit_unit(state.board[target], value, "组合")\r\n'
    '\r\n'
    'func _assemble_defer(p: Placement, fx_list: Array, when: String) -> void:\r\n',
    '\t\t\tfor target in targets:\r\n'
    '\t\t\t\tif state.board.has(target):\r\n'
    '\t\t\t\t\t_hit_unit(state.board[target], value, "组合")\r\n'
    '\t\t"self_destruct":\r\n'
    '\t\t\t# R775：幽灵「自己回合开始时，这张卡破坏」—— 走 _destroy 触发完整死亡流程\r\n'
    '\t\t\t# （含 _deathrattle → death 扳机 → 下半效果）。\r\n'
    '\t\t\tif state.board.has(cell):\r\n'
    '\t\t\t\t_destroy(cell)\r\n'
    '\r\n'
    'func _assemble_defer(p: Placement, fx_list: Array, when: String) -> void:\r\n'))

for i, (old, new) in enumerate(edits, 1):
    n = s.count(old)
    assert n == 1, '第 %d 处锚点匹配数=%d' % (i, n)
    s = s.replace(old, new)

with io.open(P, 'w', encoding='utf-8', newline='') as f:
    f.write(s)
with io.open(P, 'rb') as f:
    b = f.read()
print('game_engine.gd OK  CRLF=%d LF=%d' % (b.count(b'\r\n'), b.count(b'\n') - b.count(b'\r\n')))
