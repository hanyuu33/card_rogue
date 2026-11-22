# -*- coding: utf-8 -*-
## R857 补：真关卡装配路径（GameLevels.level_by_key + 难度缩放 + place）走一遍。
import io

P = "scripts/test_engine.gd"
src = io.open(P, encoding="utf-8", newline="").read()
NL = "\r\n"

OLD = '''	r857_e4._begin_turn(GameEngine.SIDE_SELF)
	check(r857_mine.armor == GameEngine.SLEEP_ARMOR,
			"R857 我方回合开始：我方的沉睡单位同样重置为 %d 护甲（实际 %d）" % [
				GameEngine.SLEEP_ARMOR, r857_mine.armor])


'''
NEW = '''	r857_e4._begin_turn(GameEngine.SIDE_SELF)
	check(r857_mine.armor == GameEngine.SLEEP_ARMOR,
			"R857 我方回合开始：我方的沉睡单位同样重置为 %d 护甲（实际 %d）" % [
				GameEngine.SLEEP_ARMOR, r857_mine.armor])

	# ── ⑧ 真关卡装配路径（R856 教训：只在自建 place 上签字会漏装配差异） ──
	## 走的是 battle_scene 同款的「卡库命中 → with_unit_override → 难度缩放 → place」，
	## 确认关卡里那只恶魔鸭真的会因为沉睡拿到甲壳，而不是只有单测棋盘上才行。
	RunState.set_difficulty(0)
	var r857_lvl: Dictionary = GameLevels.level_by_key("boss_demon_duck")
	check(not r857_lvl.is_empty(), "R857 恶魔鸭 Boss 关能按 key 取到（boss_demon_duck）")
	if not r857_lvl.is_empty():
		var r857_e5 := _new_engine([], 20, 30)
		for e: Array in r857_lvl["enemy_units"]:
			var r857_rc: CardData = r857_repo.get_card(int(e[0]))
			check(r857_rc != null, "R857 关卡编成里的单位都在卡库（id %d）" % int(e[0]))
			if r857_rc == null:
				continue
			r857_rc = GameLevels.with_unit_override(r857_rc, e)
			r857_rc = RunState.scaled_enemy_card(r857_rc)
			r857_e5.state.place(r857_rc, e[6], GameEngine.SIDE_OPPONENT)
		var r857_boss: Placement = r857_e5.state.unit_at(Vector2i(0, 1))
		check(r857_boss != null and r857_boss.card.id == 9116 and r857_boss.sleep_left > 0,
				"R857 真关卡：恶魔鸭在后排中央 (0,1)，开局沉睡 %d" % [
					r857_boss.sleep_left if r857_boss else -1])
		r857_e5._begin_turn(GameEngine.SIDE_OPPONENT)
		check(r857_boss != null and r857_boss.armor == GameEngine.SLEEP_ARMOR,
				"R857 真关卡：敌方回合开始后它带 %d 护甲（实际 %d）" % [
					GameEngine.SLEEP_ARMOR, r857_boss.armor if r857_boss else -1])


'''

o = OLD.replace("\n", NL)
n = NEW.replace("\n", NL)
assert src.count(o) == 1, "锚点命中 %d 次" % src.count(o)
src = src.replace(o, n, 1)
io.open(P, "w", encoding="utf-8", newline="").write(src)
print("ok", len(src))
