# -*- coding: utf-8 -*-
"""R758：test_engine 追加计量工坊三机制回归（追加到文件末尾，双换行排版一致）。"""
import io

P = "e:/work/card_rogue/scripts/test_engine.gd"
raw = io.open(P, "r", encoding="utf-8", newline="").read()
assert "\r\n" in raw
assert "R758 常数测量员" not in raw, "已追加过"

BODY = '''	# ---------------------------------------------------------------- R758 计量工坊
	# ① 常数测量员：**作为行动的代替**分配 16 点伤害（由近及远 / 溢出到 HP / 没打到 HP 就眩晕）。
	#    力 0 → 通用 AI 只会「挪一步再空手横置」，所以整条行动走专属 AI（与枭熊同一通道）。
	var r758_sv := _card(9253, "常数测量员", "盟友", 0, 0, 60, 1, 1)
	r758_sv.traits.append(GameEngine.SURVEYOR_TRAIT)
	var r758_e1 := _new_engine([], 20, 20)
	r758_e1.ai_enabled = true
	r758_e1.current_side = GameEngine.SIDE_OPPONENT
	r758_e1.state.place(r758_sv, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r758_e1.state.place(_card(8003, "农民", "盟友", 3, 0, 30, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_SELF)
	r758_e1.run_ai_unit(Vector2i(0, 1))
	var r758_wall: Placement = r758_e1.state.unit_at(Vector2i(2, 1))
	check(r758_wall != null and r758_wall.health == 14 and r758_e1.state.hp_self == 20,
			"R758 常数测量员：16 点全被单位吃掉（30 → 14），玩家 HP 一点不掉")
	check(r758_sv.stun_left == 1 and r758_sv.tapped,
			"R758 常数测量员：没打到玩家 HP → 自己眩晕一回合，且发动后算行动过")
	# ② 空场：16 点全打玩家 HP（不眩晕）。
	var r758_sv2 := _card(9253, "常数测量员", "盟友", 0, 0, 60, 1, 1)
	r758_sv2.traits.append(GameEngine.SURVEYOR_TRAIT)
	var r758_e2 := _new_engine([], 20, 20)
	r758_e2.ai_enabled = true
	r758_e2.current_side = GameEngine.SIDE_OPPONENT
	r758_e2.state.place(r758_sv2, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r758_e2.run_ai_unit(Vector2i(0, 1))
	check(r758_e2.state.hp_self == 4 and r758_sv2.stun_left == 0,
			"R758 常数测量员：场上没单位 → 16 点全打 HP（20 → 4），自己不眩晕")
	# ③ 溢出：单位只吃得下 5 点，剩下的 11 点打到 HP。
	var r758_sv3 := _card(9253, "常数测量员", "盟友", 0, 0, 60, 1, 1)
	r758_sv3.traits.append(GameEngine.SURVEYOR_TRAIT)
	var r758_e3 := _new_engine([], 20, 20)
	r758_e3.ai_enabled = true
	r758_e3.current_side = GameEngine.SIDE_OPPONENT
	r758_e3.state.place(r758_sv3, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r758_e3.state.place(_card(8003, "农民", "盟友", 3, 0, 5, 1, 1),
			Vector2i(2, 1), GameEngine.SIDE_SELF)
	r758_e3.run_ai_unit(Vector2i(0, 1))
	check(r758_e3.state.unit_at(Vector2i(2, 1)) == null and r758_e3.state.hp_self == 9
			and r758_sv3.stun_left == 0,
			"R758 常数测量员：5 血单位被打倒，剩下 11 点溢出到 HP（20 → 9），不眩晕")
	# ④ 超负荷单位「只分到刚好归零」：10 血超负荷吃 10 点（0 血存活），剩 6 点给下一个。
	var r758_sv4 := _card(9253, "常数测量员", "盟友", 0, 0, 60, 1, 1)
	r758_sv4.traits.append(GameEngine.SURVEYOR_TRAIT)
	var r758_e4 := _new_engine([], 20, 20)
	r758_e4.ai_enabled = true
	r758_e4.current_side = GameEngine.SIDE_OPPONENT
	r758_e4.state.place(r758_sv4, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var r758_ov := _card(8050, "旧式机兵", "盟友", 3, 0, 10, 1, 1)
	r758_ov.affixes.append(GameEngine.AFFIX_OVERLOAD)
	r758_e4.state.place(r758_ov, Vector2i(2, 1), GameEngine.SIDE_SELF)
	r758_e4.state.place(_card(8003, "农民", "盟友", 3, 0, 20, 1, 1),
			Vector2i(2, 0), GameEngine.SIDE_SELF)
	r758_e4.run_ai_unit(Vector2i(0, 1))
	var r758_big: Placement = r758_e4.state.unit_at(Vector2i(2, 0))
	check(r758_ov.health == 0 and r758_big != null and r758_big.health == 14,
			"R758 常数测量员：超负荷单位只分到刚好归零（10），剩下的 6 点继续给下一个")
	# ⑤ 精密计算者：对方盟友 / 工事入场后生命 > 15 → 变 15（入场增益结算完之后）。
	var r758_calc := _card(9254, "精密计算者", "盟友", 6, 6, 60, 1, 2)
	r758_calc.traits.append(GameEngine.CALCULATOR_TRAIT)
	var r758_e5 := _new_engine([], 20, 20)
	r758_e5.state.place(r758_calc, Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	var r758_p5 := r758_e5.state.place(_card(8003, "农民", "盟友", 3, 0, 30, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	r758_e5._on_ally_entered(r758_p5, GameEngine.SIDE_SELF)
	check(r758_p5.health == 15 and r758_p5.card.health == 30,
			"R758 精密计算者：我方盟友入场 30 血 → 15（只压当前生命，不动卡面生命上限）")
	# 工事也吃（`_on_ally_entered` 里 kind 判早退之前必须补一次）。
	var r758_p5b := r758_e5.state.place(_card(9998, "测试工事", "工事", 2, 0, 30, 0, 0),
			Vector2i(3, 2), GameEngine.SIDE_SELF)
	r758_e5._on_ally_entered(r758_p5b, GameEngine.SIDE_SELF)
	check(r758_p5b.health == 15, "R758 精密计算者：工事入场同样被压到 15")
	# 15 及以下不动；没有计算者时不动。
	var r758_p5c := r758_e5.state.place(_card(8003, "农民", "盟友", 3, 0, 15, 1, 1),
			Vector2i(3, 0), GameEngine.SIDE_SELF)
	r758_e5._on_ally_entered(r758_p5c, GameEngine.SIDE_SELF)
	var r758_e6 := _new_engine([], 20, 20)
	var r758_p6 := r758_e6.state.place(_card(8003, "农民", "盟友", 3, 0, 30, 1, 1),
			Vector2i(3, 1), GameEngine.SIDE_SELF)
	r758_e6._on_ally_entered(r758_p6, GameEngine.SIDE_SELF)
	check(r758_p5c.health == 15 and r758_p6.health == 30,
			"R758 精密计算者：本来就不超过 15 的不动；场上没有计算者时也不动")
	# ⑥ 负载增量员：回合开始往玩家抽牌库塞「攻击」8002 + 「木栅栏」8001。
	var r758_ld := _card(9255, "负载增量员", "盟友", 4, 4, 60, 1, 1)
	r758_ld.traits.append(GameEngine.LOADER_TRAIT)
	var r758_e7 := _new_engine([], 20, 20)
	r758_e7.state.place(r758_ld, Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var r758_deck_before := r758_e7.state.deck.size()
	r758_e7._loader_tick(GameEngine.SIDE_OPPONENT)
	var r758_has_atk := false
	var r758_has_fence := false
	for r758_c: CardData in r758_e7.state.deck:
		if r758_c.id == 8002:
			r758_has_atk = true
		if r758_c.id == 8001:
			r758_has_fence = true
	check(r758_e7.state.deck.size() == r758_deck_before + 2
			and r758_has_atk and r758_has_fence,
			"R758 负载增量员：回合开始 → 玩家抽牌库 +2（一张「攻击」+ 一张「木栅栏」）")
	var r758_gift_ok := true
	for r758_c2: CardData in r758_e7.state.deck:
		if r758_c2.id == 8002 or r758_c2.id == 8001:
			r758_gift_ok = r758_gift_ok and r758_c2.own_copy
	check(r758_gift_ok,
			"R758 负载增量员：塞进去的是独立副本（共享库实例被减费会泄漏回卡库）")
	# ⑦ 关卡编成：三只 60 血、位置 后排(0,1) / 中排(1,1) / 前排(2,1)。
	var r758_lvl := _level_named("计量工坊")
	var r758_units: Array = r758_lvl["enemy_units"]
	check(str(r758_lvl["key"]) == "metrology_works"
			and int(r758_lvl["tier"]) == GameLevels.TIER_NORMAL_HARD
			and int(r758_lvl["layer"]) == GameLayers.LAYER_TWO
			and r758_units.size() == 3,
			"R758 计量工坊：二层普通困难关卡，三只单位")
	check(int(r758_units[0][0]) == 9253 and int(r758_units[0][3]) == 60
			and (r758_units[0][6] as Vector2i) == Vector2i(0, 1)
			and int(r758_units[1][0]) == 9254 and int(r758_units[1][5]) == 2
			and (r758_units[1][6] as Vector2i) == Vector2i(1, 1)
			and int(r758_units[2][0]) == 9255 and int(r758_units[2][2]) == 4
			and (r758_units[2][6] as Vector2i) == Vector2i(2, 1),
			"R758 计量工坊：后排 0/60 常数测量员 · 中排 6/60 速2 精密计算者 · 前排 4/60 负载增量员")
	# ⑧ 三套机制一律按 trait 判（不认 id）：换了 id、trait 还在，机制照跑。
	var r758_sv8 := _card(19999, "换皮测量员", "盟友", 0, 0, 60, 1, 1)
	r758_sv8.traits.append(GameEngine.SURVEYOR_TRAIT)
	var r758_e8 := _new_engine([], 20, 20)
	r758_e8.ai_enabled = true
	r758_e8.current_side = GameEngine.SIDE_OPPONENT
	r758_e8.state.place(r758_sv8, Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r758_e8.run_ai_unit(Vector2i(0, 1))
	check(r758_e8.state.hp_self == 4,
			"R758 三机制一律按 trait 判（换 id 不换 trait 照样生效）")
'''

FMT = BODY.replace("\n", "\r\n\r\n")
raw = raw.rstrip("\r\n") + "\r\n\r\n" + FMT + "\r\n"
io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("appended", len(FMT))
