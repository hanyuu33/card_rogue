# -*- coding: utf-8 -*-
"""R810 回归：四件新道具（新月耳饰 / 太阳指环 / 海妖鱼叉 / 缺陷时钟）。

外加两处条数锁：道具总数 75 → 79、奖励池 32 → 36（一般 26 → 29 / 传奇 6 → 7）。
"""
import io

P = "E:/work/card_rogue/scripts/test_engine.gd"
s = io.open(P, encoding="utf-8", newline="").read()


def sub(old, new, cnt=1):
    global s
    old, new = old.replace("\n", "\r\n"), new.replace("\n", "\r\n")
    assert s.count(old) == cnt, (old[:50], s.count(old))
    s = s.replace(old, new)


# ---- 1. 注册 ----
sub("""	_test_r807()
	_test_r809()
""", """	_test_r807()
	_test_r809()
	_test_r810()
""")

# ---- 2. 奖励分档条数 ----
sub('''	check(r289_all.size() == 32 and r289_nor.size() == 26 and r289_leg.size() == 6,

			"奖励分档：奖励池 32 件 = 一般 26 + 传奇 6（实际 %d / %d / %d）"

			% [r289_all.size(), r289_nor.size(), r289_leg.size()])''',
'''	check(r289_all.size() == 36 and r289_nor.size() == 29 and r289_leg.size() == 7,

			"奖励分档：奖励池 36 件 = 一般 29 + 传奇 7（实际 %d / %d / %d）"

			% [r289_all.size(), r289_nor.size(), r289_leg.size()])''')

# ---- 3. 图标总数（R577b 保真锁）----
sub('''	check(icon577_src_ok and icon577_repo.all_relics().size() == 75,

			"R577b 保真锁：75 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080）")''',
'''	check(icon577_src_ok and icon577_repo.all_relics().size() == 79,

			"R577b 保真锁：79 件道具的 id 都能在 relics.json 源文本里找到（R792 +板甲 6070 / 兵 6071 / 墙砖 6072 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R805 +蜂蜜 6079 / R806 +法术卷轴 6080 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084）")''')

# ---- 4. 测试函数追加到文件末尾 ----
TEST = '''

func _test_r810() -> void:
	## R810：四件新道具。
	##   新月耳饰 6081（一般）：每 3 场战斗，在该场第一回合 +1 费用（**括号里那句不写进描述**）；
	##   太阳指环 6082（一般）：每个我方回合开始，对所有敌方单位 3 点伤害（走 `_hit_unit`）；
	##   海妖鱼叉 6083（一般）：同一回合内同一个敌人每挨 3 次伤害 → 追加 6 点；
	##   缺陷时钟 6084（传奇）：每场打出第 12 张牌 → 结束当前回合、**跳过敌方回合**。
	## 每条都先验「数据层进了池」，再验机制，最后验「没有这件道具时什么也不发生」。
	var r810_sv_relics := RunState.relics
	var r810_sv_spent := RunState.spent_relics
	var r810_sv_crescent := RunState.crescent_battles
	RunState.spent_relics = []

	# ── ① 数据层 ──
	var r810_repo := RelicRepo.load_json()
	var r810_expect := {
		6081: ["新月耳饰", "一般", "每 3 场战斗，获得 1 点费用。"],
		6082: ["太阳指环", "一般", "每个回合，对所有敌方单位造成 3 点伤害。"],
		6083: ["海妖鱼叉", "一般", "同一回合内，每对一个敌人造成 3 次伤害，对其造成 6 点伤害。"],
		6084: ["缺陷时钟", "传奇", ""],
	}
	var r810_bad: Array = []
	for r810_id: int in r810_expect.keys():
		var r810_r: Variant = r810_repo.get_relic(r810_id)
		if r810_r == null:
			r810_bad.append("%d 不在库" % r810_id)
			continue
		if r810_r.relic_name != r810_expect[r810_id][0]:
			r810_bad.append("%d 名字「%s」" % [r810_id, r810_r.relic_name])
		if r810_r.tier != r810_expect[r810_id][1]:
			r810_bad.append("%d 档位「%s」" % [r810_id, r810_r.tier])
		if r810_r.kind != "战斗" or r810_r.source != "奖励":
			r810_bad.append("%d 分类漂移" % r810_id)
		if not r810_repo.reward_ids().has(r810_id):
			r810_bad.append("%d 不在奖励池" % r810_id)
	check(r810_bad.is_empty(), "R810 数据层：四件都在库 · 战斗类 · 奖励来源 · 进奖励池（%s）"
			% str(r810_bad))
	check(r810_repo.all_relics().size() == 79, "R810 数据层：道具总数 79 件")
	check(r810_repo.normal_reward_ids().size() == 29
			and r810_repo.legendary_reward_ids().size() == 7,
			"R810 数据层：奖励池 29 一般 + 7 传奇 = 36")
	check(r810_repo.get_relic(6081).desc == "每 3 场战斗，获得 1 点费用。",
			"R810 新月耳饰：描述只写「每 3 场战斗，获得 1 点费用。」（%s）"
					% r810_repo.get_relic(6081).desc)
	check(not r810_repo.get_relic(6081).desc.contains("第一回合"),
			"R810 新月耳饰：括号里那句「在第一回合获得」不写进描述")
	check(r810_repo.get_relic(6084).desc.contains("12")
			and r810_repo.get_relic(6084).desc.contains("敌方回合"),
			"R810 缺陷时钟：描述写明「第 12 张牌」与「不进行敌方回合」")
	check(GameEngine.CRESCENT_EARING_ID == 6081 and GameEngine.SUN_RING_ID == 6082
			and GameEngine.HARPOON_ID == 6083 and GameEngine.DEFECT_CLOCK_ID == 6084,
			"R810 常量：6081 / 6082 / 6083 / 6084 与数据层同号")

	# ── ② 新月耳饰：3 场发 1 费 ──
	RunState.relics = [6081]
	RunState.crescent_battles = 0
	check(RunState.crescent_left() == 3, "R810 新月耳饰：刚拿到时还差 3 场")
	check(RunState.crescent_tick() == false and RunState.crescent_left() == 2,
			"R810 新月耳饰：第 1 场不发，还差 2 场")
	check(RunState.crescent_tick() == false and RunState.crescent_left() == 1,
			"R810 新月耳饰：第 2 场不发，还差 1 场")
	check(RunState.crescent_tick() == true and RunState.crescent_battles == 0,
			"R810 新月耳饰：第 3 场发钱并归零重数")
	check(RunState.relic_badge_text(6081) == "3", "R810 角标：刚发完 → 画 3")
	RunState.crescent_battles = 1
	check(RunState.relic_badge_text(6081) == "2", "R810 角标：打过 1 场 → 画 2")
	check(RunState.relic_state_note(6081).contains("2"),
			"R810 面板：状态注写「还差 2 场」（%s）" % RunState.relic_state_note(6081))

	# 引擎侧：首回合的费用确实多 1 点（与「什么都不带」逐字对比）
	RunState.relics = []
	RunState.crescent_battles = 0
	var r810_e0 := _new_engine([], 40, 40)
	r810_e0._begin_turn(GameEngine.SIDE_SELF)
	var r810_base: int = r810_e0.state.energy
	RunState.relics = [6081]
	RunState.crescent_battles = 2      # 这一场正好是第 3 场
	var r810_e1 := _new_engine([], 40, 40)
	r810_e1._begin_turn(GameEngine.SIDE_SELF)
	check(r810_e1.state.energy == r810_base + 1,
			"R810 新月耳饰：第 3 场首回合费用 %d → %d（+1）"
			% [r810_base, r810_e1.state.energy])
	RunState.crescent_battles = 0      # 刚落过账 → 下一场不该再发
	var r810_e2 := _new_engine([], 40, 40)
	r810_e2._begin_turn(GameEngine.SIDE_SELF)
	check(r810_e2.state.energy == r810_base,
			"R810 新月耳饰：计数归零后的那一场不发（%d == %d）"
			% [r810_e2.state.energy, r810_base])

	# ── ③ 太阳指环：每个我方回合开始打全体敌人 3 点 ──
	var r810_cards := CardRepo.load_json()
	RunState.relics = [6082]
	var r810_e3 := _new_engine([], 40, 40)
	var r810_foe := r810_e3.state.place(
			CardData.from_dict(r810_cards.get_card(1051).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r810_ally := r810_e3.state.place(
			CardData.from_dict(r810_cards.get_card(1011).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	var r810_f0: int = r810_foe.health
	var r810_a0: int = r810_ally.health
	r810_e3._begin_turn(GameEngine.SIDE_SELF)
	check(r810_foe.health == r810_f0 - 3,
			"R810 太阳指环：我方回合开始，敌人 %d → %d（-3）"
			% [r810_f0, r810_foe.health])
	check(r810_ally.health == r810_a0,
			"R810 太阳指环：只打敌人，己方单位不掉血")
	r810_e3.end_turn()     # 我方 → 敌方
	r810_e3.end_turn()     # 敌方 → 我方（第二个我方回合）
	check(r810_foe.health == r810_f0 - 6,
			"R810 太阳指环：第二个我方回合再打一次（累计 -6，实际 %d）"
			% (r810_f0 - r810_foe.health))

	# 没有道具 → 一点血都不掉
	RunState.relics = []
	var r810_e4 := _new_engine([], 40, 40)
	var r810_foe2 := r810_e4.state.place(
			CardData.from_dict(r810_cards.get_card(1051).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r810_f2: int = r810_foe2.health
	r810_e4._begin_turn(GameEngine.SIDE_SELF)
	check(r810_foe2.health == r810_f2, "R810 太阳指环：没道具时回合开始不掉血")

	# ── ④ 海妖鱼叉：同一回合内同一个敌人每 3 次伤害 → 追加 6 ──
	RunState.relics = [6083]
	var r810_e5 := _new_engine([], 40, 40)
	r810_e5.current_side = GameEngine.SIDE_SELF
	var r810_p5 := r810_e5.state.place(
			CardData.from_dict(r810_cards.get_card(1051).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r810_other := r810_e5.state.place(
			CardData.from_dict(r810_cards.get_card(1011).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	var r810_h5: int = r810_p5.health
	var r810_ho: int = r810_other.health
	r810_e5._hit_unit(r810_p5, 1, "测试")
	r810_e5._hit_unit(r810_p5, 1, "测试")
	check(r810_p5.health == r810_h5 - 2,
			"R810 海妖鱼叉：前 2 次不追加（%d）" % (r810_h5 - r810_p5.health))
	check(r810_other.health == r810_ho,
			"R810 海妖鱼叉：另一个敌人各自记账，不会被牵连")
	r810_e5._hit_unit(r810_p5, 1, "测试")
	check(r810_p5.health == r810_h5 - 3 - 6,
			"R810 海妖鱼叉：第 3 次 → 1 点 + 追加 6 点（累计 %d）"
			% (r810_h5 - r810_p5.health))
	r810_e5._hit_unit(r810_p5, 1, "测试")
	r810_e5._hit_unit(r810_p5, 1, "测试")
	r810_e5._hit_unit(r810_p5, 1, "测试")
	check(r810_p5.health == r810_h5 - 6 - 12,
			"R810 海妖鱼叉：第 6 次再追加一次（累计 %d）" % (r810_h5 - r810_p5.health))
	# 换回合（turn_number +1）→ 计数从 0 重算
	var r810_h5b: int = r810_p5.health
	r810_e5.turn_number += 1
	r810_e5._hit_unit(r810_p5, 1, "测试")
	r810_e5._hit_unit(r810_p5, 1, "测试")
	check(r810_p5.health == r810_h5b - 2,
			"R810 海妖鱼叉：新回合从 0 数，前两次不追加")
	# 敌方回合里打的不算（「同一回合」= 我方回合）
	var r810_h5c: int = r810_p5.health
	r810_e5.turn_number += 1
	r810_e5.current_side = GameEngine.SIDE_OPPONENT
	for _k in 3:
		r810_e5._hit_unit(r810_p5, 1, "测试")
	check(r810_p5.health == r810_h5c - 3,
			"R810 海妖鱼叉：敌方回合里的伤害不攒层（只掉 3 点）")
	# 没道具 → 怎么打都不追加
	RunState.relics = []
	var r810_e6 := _new_engine([], 40, 40)
	r810_e6.current_side = GameEngine.SIDE_SELF
	var r810_p6 := r810_e6.state.place(
			CardData.from_dict(r810_cards.get_card(1051).to_dict()),
			Vector2i(1, 0), GameEngine.SIDE_OPPONENT)
	var r810_h6: int = r810_p6.health
	for _k2 in 6:
		r810_e6._hit_unit(r810_p6, 1, "测试")
	check(r810_p6.health == r810_h6 - 6, "R810 海妖鱼叉：没道具时打 6 次只掉 6 点")

	# ── ⑤ 缺陷时钟：第 12 张牌 → 跳过敌方回合 ──
	RunState.relics = [6084]
	var r810_e7 := _new_engine([], 40, 40)
	r810_e7._begin_turn(GameEngine.SIDE_SELF)
	var r810_t0: int = r810_e7.turn_number
	# 第 11 张：不触发
	r810_e7.state.energy = 30
	r810_e7.state.hand.clear()
	r810_e7.state.hand.append(CardData.from_dict(r810_cards.get_card(8006).to_dict()))
	r810_e7._clock_plays = 10
	r810_e7.play_from_hand(0, Vector2i(4, 1))
	check(r810_e7.current_side == GameEngine.SIDE_SELF
			and r810_e7.turn_number == r810_t0 and r810_e7.opp_turns == 0,
			"R810 缺陷时钟：第 11 张牌不触发（仍在第 %d 回合）" % r810_e7.turn_number)
	# 第 12 张：结束当前回合 + 立刻开始新的我方回合，敌方回合一次都没走
	r810_e7.state.energy = 30
	r810_e7.state.hand.clear()
	r810_e7.state.hand.append(CardData.from_dict(r810_cards.get_card(8006).to_dict()))
	r810_e7.play_from_hand(0, Vector2i(4, 0))
	check(r810_e7.turn_number == r810_t0 + 1,
			"R810 缺陷时钟：第 12 张牌 → 新回合（%d → %d）"
			% [r810_t0, r810_e7.turn_number])
	check(r810_e7.current_side == GameEngine.SIDE_SELF,
			"R810 缺陷时钟：回合仍是我方")
	check(r810_e7.opp_turns == 0,
			"R810 缺陷时钟：敌方回合完全没有开始（opp_turns %d）" % r810_e7.opp_turns)
	check(r810_e7.state.energy > 0,
			"R810 缺陷时钟：新回合照常发费（%d）" % r810_e7.state.energy)
	# 一场只触发一次：再打一张不会又跳回合
	var r810_t1: int = r810_e7.turn_number
	r810_e7.state.energy = 30
	r810_e7.state.hand.clear()
	r810_e7.state.hand.append(CardData.from_dict(r810_cards.get_card(8006).to_dict()))
	r810_e7.play_from_hand(0, Vector2i(4, 1))
	check(r810_e7.turn_number == r810_t1 and r810_e7.opp_turns == 0,
			"R810 缺陷时钟：一场只触发一次（第 13 张不再跳）")
	# 没道具 → 第 12 张什么也不发生
	RunState.relics = []
	var r810_e8 := _new_engine([], 40, 40)
	r810_e8._begin_turn(GameEngine.SIDE_SELF)
	var r810_t8: int = r810_e8.turn_number
	r810_e8.state.energy = 30
	r810_e8.state.hand.clear()
	r810_e8.state.hand.append(CardData.from_dict(r810_cards.get_card(8006).to_dict()))
	r810_e8._clock_plays = 11
	r810_e8.play_from_hand(0, Vector2i(4, 1))
	check(r810_e8.turn_number == r810_t8 and r810_e8.current_side == GameEngine.SIDE_SELF
			and r810_e8.opp_turns == 0,
			"R810 缺陷时钟：没道具时第 12 张不跳回合")

	# ── ⑥ 源码守卫（口径不许被后来的改动悄悄改回去）──
	var r810_eng_src := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r810_eng_src.contains("func end_turn(skip_enemy: bool = false) -> void :"),
			"R810 守卫：`end_turn` 保留 `skip_enemy` 形参（缺陷时钟唯一的换回合通道）")
	var r810_clock_calls := 0
	for r810_ln in r810_eng_src.split("\\n"):
		if r810_ln.strip_edges() == "_clock_maybe_switch()":
			r810_clock_calls += 1
	check_src(r810_clock_calls == 3,
			"R810 守卫：三个公共出牌入口（play_from_hand / use_spell / use_effect）各调一次"
					+ " `_clock_maybe_switch`（实际 %d 处）" % r810_clock_calls)
	var r810_place_src := FileAccess.get_file_as_string("res://scripts/placement.gd")
	check_src(r810_place_src.contains('"harpoon_hits", "harpoon_turn"'),
			"R810 守卫：鱼叉计数进了 Placement 存档字段（否则续档归零）")

	# 收尾还原
	RunState.relics = r810_sv_relics
	RunState.spent_relics = r810_sv_spent
	RunState.crescent_battles = r810_sv_crescent
'''

s = s.rstrip("\r\n") + TEST.replace("\n", "\r\n") + "\r\n"
io.open(P, "w", encoding="utf-8", newline="").write(s)
print("TEST OK, CRLF:", "\r\n" in s)
