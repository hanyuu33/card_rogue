# -*- coding: utf-8 -*-
## R859：把 _test_r857（沉睡甲壳）整段重写成新口径。
import io

P = "scripts/test_engine.gd"
src = io.open(P, encoding="utf-8", newline="").read()
NL = "\r\n"

START = "func _test_r857() -> void:"
END = "func _test_r856() -> void:"
i = src.index(START)
j = src.index(END)

NEW = '''func _test_r857() -> void :
	## R857 建壳 / R859 改口径（店长：开局 10 护甲、不重置、醒来失去所有护甲）：
	## 沉睡单位**一上场就带 GameEngine.SLEEP_ARMOR 点甲壳**，甲还在时挨打**不算「挨打」**
	## （自动伤害道具因此打不醒它），醒来那一刻**失去全部护甲**。
	## 钉九件事：常量 / 上场即带甲 / 回合开始不重置 / 无 trait 不误伤 / 玩家侧对称 /
	## 甲挡伤害不计挨打 / 破甲那一下才算 / 两个醒来口都清空 / 真关卡装配路径。
	var r857_repo := CardRepo.load_json()
	var r857_duck: CardData = r857_repo.get_card(9116)
	check(r857_duck != null and r857_duck.traits.has(FieldState.SLEEP_TRAIT),
			"R859 恶魔鸭 9116 带「沉睡」trait（甲壳的唯一判据）")
	if r857_duck == null:
		return
	check(GameEngine.SLEEP_ARMOR == 10,
			"R859 沉睡甲壳常量 = 10（实际 %d）" % GameEngine.SLEEP_ARMOR)

	# ── ① 一上场就有甲（place 是唯一初始化口） ──
	var r857_e := _new_engine([], 30, 30)
	var r857_p := r857_e.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	check(r857_p.sleep_left == FieldState.SLEEP_TURNS and r857_p.armor == GameEngine.SLEEP_ARMOR,
			"R859 刚上场：睡眠 %d 点 + 直接带 %d 护甲（实际 sleep %d / armor %d）" % [
				FieldState.SLEEP_TURNS, GameEngine.SLEEP_ARMOR,
				r857_p.sleep_left, r857_p.armor])

	# ── ② 回合开始**不重置**（这是 R859 与 R857 的分界） ──
	r857_e._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r857_p.armor == GameEngine.SLEEP_ARMOR,
			"R859 自己回合开始：护甲保持 %d（不是重置/叠加）" % r857_p.armor)
	r857_p.armor = 4
	r857_e._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r857_p.armor == 4,
			"R859 被磨到 4 之后过一回合仍是 4（**不重置**，实际 %d）" % r857_p.armor)

	# ── ③ 没有「沉睡」trait 的单位不会被误伤 ──
	var r857_fodder := r857_e.state.place(
			CardData.from_dict(r857_repo.get_card(9001).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	check(r857_fodder.armor == 0,
			"R859 普通单位上场不带甲（实际 %d）" % r857_fodder.armor)

	# ── ④ 甲还在时挨打**不算「挨打」**（自动伤害道具打不醒它） ──
	var r857_e2 := _new_engine([], 30, 30)
	var r857_p2 := r857_e2.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	var r857_hp0: int = r857_p2.health
	var r857_sleep0: int = r857_p2.sleep_left
	r857_e2._hit_unit(r857_p2, 3, "测试")
	check(r857_p2.health == r857_hp0
			and r857_p2.armor == GameEngine.SLEEP_ARMOR - 3
			and r857_p2.sleep_left == r857_sleep0,
			"R859 甲还在时挨 3 点：血不动、甲 10→%d、**沉睡计数不变**（仍 %d）" % [
				r857_p2.armor, r857_p2.sleep_left])

	# ── ⑤ 把甲打穿的那一下才算挨打 ──
	r857_e2._hit_unit(r857_p2, GameEngine.SLEEP_ARMOR, "测试")
	check(r857_p2.armor == 0 and r857_p2.health == r857_hp0 - 3
			and r857_p2.sleep_left == r857_sleep0 - 1,
			"R859 打穿甲壳：甲归零、溢出扣血 %d、沉睡 -1（剩 %d）" % [
				r857_hp0 - r857_p2.health, r857_p2.sleep_left])

	# ── ⑥ 回合口睡满 → 醒来同时**失去所有护甲** ──
	r857_p2.sleep_left = 1
	r857_p2.armor = GameEngine.SLEEP_ARMOR
	r857_e2._sleep_tick(GameEngine.SIDE_OPPONENT)
	check(r857_p2.sleep_left == 0 and r857_p2.armor == 0,
			"R859 回合口醒来：甲壳整个脱落（sleep %d / armor %d）" % [
				r857_p2.sleep_left, r857_p2.armor])

	# ── ⑦ 受伤口被打醒 → 同样失去所有护甲（两个醒来口一致） ──
	var r857_e3 := _new_engine([], 30, 30)
	var r857_p3 := r857_e3.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r857_p3.sleep_left = 1
	r857_p3.armor = GameEngine.SLEEP_ARMOR + GameEngine.HECATE_ARMOR_GAIN
	r857_e3._demon_duck_hurt(r857_p3, Vector2i(0, 1), 5)
	check(r857_p3.sleep_left == 0 and r857_p3.armor == 0,
			"R859 受伤口醒来：连赫卡那 +%d 一起清空（15 → %d）" % [
				GameEngine.HECATE_ARMOR_GAIN, r857_p3.armor])

	# ── ⑧ 玩家侧对称（判据只看 trait / sleep_left，不认阵营） ──
	var r857_e4 := _new_engine([], 30, 30)
	var r857_mine := r857_e4.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	check(r857_mine.armor == GameEngine.SLEEP_ARMOR,
			"R859 我方沉睡单位同样带 %d 护甲（实际 %d）" % [
				GameEngine.SLEEP_ARMOR, r857_mine.armor])

	# ── ⑨ 真关卡装配路径（R856 教训：别只在自建 place 上签字） ──
	## 走 battle_scene 同款的「卡库命中 → with_unit_override → 难度缩放 → place」。
	RunState.set_difficulty(0)
	var r857_lvl: Dictionary = GameLevels.level_by_key("boss_demon_duck")
	check(not r857_lvl.is_empty(), "R859 恶魔鸭 Boss 关能按 key 取到（boss_demon_duck）")
	if not r857_lvl.is_empty():
		var r857_e5 := _new_engine([], 20, 30)
		for e: Array in r857_lvl["enemy_units"]:
			var r857_rc: CardData = r857_repo.get_card(int(e[0]))
			check(r857_rc != null, "R859 关卡编成里的单位都在卡库（id %d）" % int(e[0]))
			if r857_rc == null:
				continue
			r857_rc = GameLevels.with_unit_override(r857_rc, e)
			r857_rc = RunState.scaled_enemy_card(r857_rc)
			r857_e5.state.place(r857_rc, e[6], GameEngine.SIDE_OPPONENT)
		var r857_boss: Placement = r857_e5.state.unit_at(Vector2i(0, 1))
		check(r857_boss != null and r857_boss.card.id == 9116
				and r857_boss.armor == GameEngine.SLEEP_ARMOR,
				"R859 真关卡：恶魔鸭开局就带 %d 护甲（实际 %d）" % [
					GameEngine.SLEEP_ARMOR, r857_boss.armor if r857_boss else -1])


'''

src = src[:i] + NEW.replace("\n", NL) + src[j:]
io.open(P, "w", encoding="utf-8", newline="").write(src)
print("ok", len(src))
