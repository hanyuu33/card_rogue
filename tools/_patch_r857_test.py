# -*- coding: utf-8 -*-
## R857：沉睡甲壳单测（插入 test_engine.gd 的 _test_r856 之前 + 注册）。
import io

P = "scripts/test_engine.gd"
src = io.open(P, encoding="utf-8", newline="").read()
orig = src
NL = "\r\n"


def rep(old, new, tag):
    global src
    o = old.replace("\n", NL)
    n = new.replace("\n", NL)
    c = src.count(o)
    assert c == 1, "[%s] 锚点命中 %d 次" % (tag, c)
    src = src.replace(o, n, 1)


TEST = '''func _test_r857() -> void:
	## R857：沉睡「甲壳」—— 沉睡中的单位每回合获得 5 护甲，回合开始**重置**（覆盖不叠加），
	## 醒来那一刻甲壳碎裂（只扣这 5 点，别处攒的护甲留着）。
	## 钉七件事：常量 / 上场无甲 / 自己回合开始给 5 / 重置而非累加 / 无 trait 不误伤 /
	## 两个醒来口都碎甲 / 玩家侧对称。
	var r857_repo := CardRepo.load_json()
	var r857_duck: CardData = r857_repo.get_card(9116)
	check(r857_duck != null and r857_duck.traits.has(FieldState.SLEEP_TRAIT),
			"R857 恶魔鸭 9116 带「沉睡」trait（甲壳的唯一判据）")
	if r857_duck == null:
		return
	check(GameEngine.SLEEP_ARMOR == 5,
			"R857 沉睡甲壳常量 = 5（实际 %d）" % GameEngine.SLEEP_ARMOR)

	# ── ① 上场即沉睡，但**当回合还没有甲**（甲壳从它自己的第一个回合开始给） ──
	var r857_e := _new_engine([], 30, 30)
	var r857_p := r857_e.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	check(r857_p.sleep_left == FieldState.SLEEP_TURNS and r857_p.armor == 0,
			"R857 刚上场：睡眠 %d 点、护甲 0（甲壳要等自己的回合开始）" % r857_p.sleep_left)
	r857_e._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r857_p.armor == GameEngine.SLEEP_ARMOR,
			"R857 自己回合开始：沉睡单位获得 %d 护甲（实际 %d）" % [
				GameEngine.SLEEP_ARMOR, r857_p.armor])

	# ── ② 重置而不是累加 ──
	r857_p.armor = 3
	r857_e._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r857_p.armor == GameEngine.SLEEP_ARMOR,
			"R857 被削剩 3 → 下个自己回合开始重置回 5（不是 3+5=8）")
	r857_p.armor = 17
	r857_e._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r857_p.armor == GameEngine.SLEEP_ARMOR,
			"R857 别处攒到 17 → 回合开始仍**重置**为 5（以本口为准）")

	# ── ③ 没有「沉睡」trait 的单位不会被误伤 ──
	var r857_fodder := r857_e.state.place(
			CardData.from_dict(r857_repo.get_card(9001).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	r857_fodder.armor = 2
	r857_e._begin_turn(GameEngine.SIDE_OPPONENT)
	check(r857_fodder.armor == 2,
			"R857 醒着的单位：回合开始护甲不动（实际 %d）" % r857_fodder.armor)

	# ── ④ 回合口睡满 → 醒来同时碎甲 ──
	r857_p.sleep_left = 1
	r857_p.armor = GameEngine.SLEEP_ARMOR
	r857_e._sleep_tick(GameEngine.SIDE_OPPONENT)
	check(r857_p.sleep_left == 0 and r857_p.armor == 0,
			"R857 回合口睡满醒来：甲壳一并清空（sleep %d / armor %d）" % [
				r857_p.sleep_left, r857_p.armor])

	# ── ⑤ 受伤口被打醒 → 同样碎甲（两个醒来口必须一致） ──
	var r857_e2 := _new_engine([], 30, 30)
	var r857_p2 := r857_e2.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r857_p2.sleep_left = 1
	r857_p2.armor = GameEngine.SLEEP_ARMOR
	r857_e2._demon_duck_hurt(r857_p2, Vector2i(0, 1))
	check(r857_p2.sleep_left == 0 and r857_p2.armor == 0,
			"R857 受伤口被打醒：甲壳同样碎裂（sleep %d / armor %d）" % [
				r857_p2.sleep_left, r857_p2.armor])

	# ── ⑥ 碎甲只扣 SLEEP_ARMOR：赫卡同克瑞斯那类加甲不能连坐 ──
	var r857_e3 := _new_engine([], 30, 30)
	var r857_p3 := r857_e3.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(0, 1), GameEngine.SIDE_OPPONENT)
	r857_p3.sleep_left = 1
	r857_p3.armor = GameEngine.SLEEP_ARMOR + GameEngine.HECATE_ARMOR_GAIN
	r857_e3._sleep_tick(GameEngine.SIDE_OPPONENT)
	check(r857_p3.armor == GameEngine.HECATE_ARMOR_GAIN,
			"R857 醒来只扣甲壳那 %d 点，赫卡的 +%d 保留（%d → %d）" % [
				GameEngine.SLEEP_ARMOR, GameEngine.HECATE_ARMOR_GAIN,
				GameEngine.SLEEP_ARMOR + GameEngine.HECATE_ARMOR_GAIN, r857_p3.armor])

	# ── ⑦ 玩家侧对称（判据只看 sleep_left，不认阵营 / id） ──
	var r857_e4 := _new_engine([], 30, 30)
	var r857_mine := r857_e4.state.place(CardData.from_dict(r857_duck.to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	r857_e4._begin_turn(GameEngine.SIDE_SELF)
	check(r857_mine.armor == GameEngine.SLEEP_ARMOR,
			"R857 我方回合开始：我方的沉睡单位同样重置为 %d 护甲（实际 %d）" % [
				GameEngine.SLEEP_ARMOR, r857_mine.armor])


'''

rep("func _test_r856() -> void:\n", TEST + "func _test_r856() -> void:\n", "insert")
rep("	_test_r856()\n", "	_test_r856()\n	_test_r857()\n", "register")

assert src != orig
io.open(P, "w", encoding="utf-8", newline="").write(src)
print("ok", len(orig), "->", len(src))
