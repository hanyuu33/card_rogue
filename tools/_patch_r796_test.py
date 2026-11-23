#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 测试：test_engine 数量断言 + _test_r796；test_traps 工具数量与两件新工具。"""
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


# ══ test_engine.gd ════════════════════════════════════════════
R796 = '''func _test_r796() -> void:
	## R796（用户口径）：刺墙**扩面**（工事 + HP 被攻击）/ 兔脚 6076 / 钻头 6077 /
	## 卡牌包 7013（随机卡填满手牌）/ 智慧药剂 7014（抽 3 张）。
	var r796_cards := CardRepo.load_json()
	var r796_relic_repo := RelicRepo.load_json()
	var r796_trap_repo := TrapRepo.load_json()
	var r796_sv_relics: Array[int] = RunState.relics.duplicate()
	var r796_sv_traps: Array[int] = RunState.traps.duplicate()
	var r796_sv_seq := RunState.tool_roll_seq
	var r796_sv_pledge := RunState.tool_drop_pledge

	# ① 数据层：两件道具在库、都进奖励池且是一般档；两件工具在库
	check(r796_relic_repo.get_relic(6076) != null and r796_relic_repo.get_relic(6077) != null,
			"R796 数据层：兔脚 6076 / 钻头 6077 都在库")
	check(r796_relic_repo.reward_ids().has(6076) and r796_relic_repo.reward_ids().has(6077)
			and r796_relic_repo.normal_reward_ids().has(6076)
			and r796_relic_repo.normal_reward_ids().has(6077),
			"R796 兔脚 / 钻头都进奖励池且都在「一般」档")
	check(r796_trap_repo.get_trap(7013) != null and r796_trap_repo.get_trap(7014) != null
			and r796_trap_repo.get_trap(7013).fill_hand
			and r796_trap_repo.get_trap(7014).draw_cards == 3
			and r796_trap_repo.get_trap(7013).is_usable()
			and r796_trap_repo.get_trap(7014).is_usable(),
			"R796 数据层：卡牌包 7013（fill_hand）/ 智慧药剂 7014（draw_cards 3）都是使用型")

	# ② 刺墙扩面：敌人**直击我方 HP** → 攻击者 -5（原来只管工事，这条永远不触发）
	var r796_sw_relics: Array[int] = [6073]
	RunState.relics = r796_sw_relics
	var r796_sw := _new_engine([], 40, 40)
	var r796_foe := r796_sw.state.place(
			CardData.from_dict(r796_cards.get_card(1011).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
	check(r796_foe != null, "R796 刺墙扩面：攻击者就位")
	var r796_foe_hp0: int = r796_foe.health
	r796_sw.attack_hp(Vector2i(4, 2), Vector2i(-1, -1), GameEngine.SIDE_OPPONENT)
	check(r796_foe.health == r796_foe_hp0 - 5,
			"R796 刺墙扩面：直击 HP → 攻击者 -5（%d → %d）" % [r796_foe_hp0, r796_foe.health])

	# ③ 不持道具时直击 HP 不反伤
	RunState.relics = []
	var r796_sw2 := _new_engine([], 40, 40)
	var r796_foe2 := r796_sw2.state.place(
			CardData.from_dict(r796_cards.get_card(1011).to_dict()),
			Vector2i(4, 2), GameEngine.SIDE_OPPONENT)
	var r796_foe2_hp0: int = r796_foe2.health
	r796_sw2.attack_hp(Vector2i(4, 2), Vector2i(-1, -1), GameEngine.SIDE_OPPONENT)
	check(r796_foe2.health == r796_foe2_hp0,
			"R796 刺墙扩面：没持道具 → 直击 HP 不反伤（攻击者仍 %d）" % r796_foe2.health)

	# ④ 兔脚：战后金币 +10（没有道具 = 0）
	check(RunState.rabbit_foot_gold() == 0, "R796 兔脚：没有道具 → 战后金币 +0")
	RunState.relics = [6076]
	check(RunState.rabbit_foot_gold() == 10, "R796 兔脚：持有 → 战后金币 +10")

	# ⑤ 兔脚：工具掉率**加算** 10%（300 场对比，走派生流所以确定性）
	RunState.relics = []
	RunState.tool_drop_pledge = 0
	RunState.tool_roll_seq = 0
	var r796_hits_plain := 0
	for i in 300:
		if RunState.roll_battle_tool_drop() > 0:
			r796_hits_plain += 1
	RunState.relics = [6076]
	RunState.tool_drop_pledge = 0
	RunState.tool_roll_seq = 0
	var r796_hits_rabbit := 0
	for i in 300:
		if RunState.roll_battle_tool_drop() > 0:
			r796_hits_rabbit += 1
	check(r796_hits_rabbit > r796_hits_plain + 15,
			"R796 兔脚：掉率加算 10%（300 场 %d → %d 次掉落）"
			% [r796_hits_plain, r796_hits_rabbit])

	# ⑥ 钻头：X ≥ 6 翻倍、X < 6 不动；没道具一律不翻
	RunState.relics = [6077]
	var r796_dr := _new_engine([], 40, 40)
	check(r796_dr._drill_x(5) == 5 and r796_dr._drill_x(6) == 12 and r796_dr._drill_x(9) == 18,
			"R796 钻头：X<6 不变 / X=6 → 12 / X=9 → 18")
	RunState.relics = []
	check(r796_dr._drill_x(6) == 6, "R796 钻头：没持道具 → X 不翻倍")

	# ⑦ 钻头：法术（流星雨）与单位（枭熊）两条 X 必须同一个口
	var r796_ge_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r796_ge_src.contains("_x_spell_value = _drill_x(")
			and r796_ge_src.contains("x_unit = _drill_x("),
			"R796 钻头：法术与枭熊两条 X 都过 `_drill_x()`（半边生效是最难查的一类）")

	# ⑧ 智慧药剂：抽 3 张
	RunState.traps = [7014, -1, -1]
	var r796_deck: Array[CardData] = []
	for i in 5:
		r796_deck.append(CardData.from_dict(r796_cards.get_card(8001).to_dict()))
	var r796_wis := _new_engine(r796_deck, 40, 40)
	var r796_hand0: int = r796_wis.state.hand.size()
	var r796_wis_ok := r796_wis.use_tool(7014, 0)
	check(r796_wis_ok and r796_wis.state.hand.size() == r796_hand0 + 3,
			"R796 智慧药剂：抽 3 张（%d → %d）" % [r796_hand0, r796_wis.state.hand.size()])

	# ⑨ 卡牌包：把空手牌填到上限；手牌已满时**拒绝使用**（不能白吃一件消耗品）
	RunState.traps = [7013, -1, -1]
	var r796_pack := _new_engine([], 40, 40)
	r796_pack.state.hand.clear()
	var r796_pack_ok := r796_pack.use_tool(7013, 0)
	check(r796_pack_ok and r796_pack.state.hand.size() == FieldState.HAND_LIMIT,
			"R796 卡牌包：手牌填到上限 %d（实际 %d）"
			% [FieldState.HAND_LIMIT, r796_pack.state.hand.size()])
	check(not r796_pack.use_tool(7013, 0), "R796 卡牌包：手牌已满时拒绝使用")

	RunState.relics = r796_sv_relics
	RunState.traps = r796_sv_traps
	RunState.tool_roll_seq = r796_sv_seq
	RunState.tool_drop_pledge = r796_sv_pledge
	print("  · R796：刺墙扩面 / 兔脚 / 钻头 / 卡牌包 / 智慧药剂")


'''

patch("scripts/test_engine.gd", [
    ('	check(r289_all.size() == 27 and r289_nor.size() == 21 and r289_leg.size() == 6,\n',
     '	check(r289_all.size() == 29 and r289_nor.size() == 23 and r289_leg.size() == 6,\n',
     "(奖励池 27→29)"),
    ('"奖励分档：奖励池 27 件 = 一般 21 + 传奇 6（实际 %d / %d / %d）"',
     '"奖励分档：奖励池 29 件 = 一般 23 + 传奇 6（实际 %d / %d / %d）"',
     "(奖励池文案)"),
    ('	check(icon577_src_ok and icon577_repo.all_relics().size() == 69,\n',
     '	check(icon577_src_ok and icon577_repo.all_relics().size() == 71,\n',
     "(道具 69→71)"),
    ('"R577b 保真锁：69 件道具的 id 都能在 relics.json 源文本里找到（R793 +刺墙 6073 / 应急装甲 6074）")',
     '"R577b 保真锁：71 件道具的 id 都能在 relics.json 源文本里找到（R796 +兔脚 6076 / 钻头 6077）")',
     "(道具文案)"),
    ('func _test_r793() -> void:', R796 + 'func _test_r793() -> void:', "(+_test_r796)"),
    ('	_test_r793()\n\n', '	_test_r793()\n	_test_r796()\n\n', "(注册)"),
])

# ══ test_traps.gd ═════════════════════════════════════════════
patch("scripts/test_traps.gd", [
    ('	check(repo.size() == 12, "traps.json 恰好 12 件工具（4 放置 + 1 直接伤害 + 7 使用型）")',
     '	check(repo.size() == 14, "traps.json 恰好 14 件工具（4 放置 + 1 直接伤害 + 9 使用型）")',
     "(工具 12→14)"),
    ('	check(repo.random_traps().size() == 10 and repo.get_trap(7007) != null,\n'
     '			"烤肉：`random_traps()` 把它排除（10 件可随机），全量仍是 12 件")',
     '	check(repo.random_traps().size() == 12 and repo.get_trap(7007) != null,\n'
     '			"烤肉：`random_traps()` 把它排除（12 件可随机），全量仍是 14 件")',
     "(随机池 10→12)"),
    ('	check(shop_pool.size() == 7 and not shop_ids.has(7007)',
     '	check(shop_pool.size() == 9 and not shop_ids.has(7007)',
     "(商店池 7→9)"),
    ('			"`shop_traps()` = 7 件有售价的（烤肉与三件非卖品都被排除）")',
     '			"`shop_traps()` = 9 件有售价的（烤肉与三件非卖品都被排除；R796 两件新工具有售价）")',
     "(商店池文案)"),
    ('	check(not drop_ids.has(7012), "石头不进随机掉落 / 工具箱池（no_drop）")',
     '	check(not drop_ids.has(7012), "石头不进随机掉落 / 工具箱池（no_drop）")\n'
     '	# R796：卡牌包 7013（随机卡填满手牌）/ 智慧药剂 7014（抽 3 张）——\n'
     '	# 都是使用型、都有售价（能掉落也能买），进商店也进随机池。\n'
     '	var cardpack: TrapData = repo.get_trap(7013)\n'
     '	var wisdom: TrapData = repo.get_trap(7014)\n'
     '	check(cardpack != null and cardpack.trap_name == "卡牌包" and cardpack.fill_hand\n'
     '			and cardpack.price == 55 and cardpack.is_usable(),\n'
     '			"卡牌包 7013：fill_hand / 使用型 / 55 金")\n'
     '	check(wisdom != null and wisdom.trap_name == "智慧药剂" and wisdom.draw_cards == 3\n'
     '			and wisdom.price == 40 and wisdom.is_usable(),\n'
     '			"智慧药剂 7014：抽 3 张 / 使用型 / 40 金")\n'
     '	check(shop_ids.has(7013) and shop_ids.has(7014)\n'
     '			and drop_ids.has(7013) and drop_ids.has(7014),\n'
     '			"R796 两件新工具：既进商店货架、也进随机掉落池")',
     "(+7013/7014 断言)"),
    ('		for tid in ["7005", "7006", "7007", "7008", "7009", "7010", "7011"]:',
     '		for tid in ["7005", "7006", "7007", "7008", "7009", "7010", "7011",\n'
     '				"7013", "7014"]:',
     "(说明文案覆盖)"),
])

print("DONE")
