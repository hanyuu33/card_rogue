extends SceneTree
## 只读探针：野兽之心 9036 多张叠加实测（2026-11-12）
## 用户报障：「野兽之心目前好像多张不能正确叠加」。
## 本探针不改任何数据，只回答三个问题：
##   ① 打出 n 张后，效果区里到底有几张（入口有没有去重）；
##   ② 从手牌使用盟友时的落地生命（卡面 +2/张）；
##   ③ 我方盟友攻击伤害（卡面 +1/张）。
## 跑法：Godot --headless --path . --script res://tools/probe_r617_beast_stack.gd

const BEAST_ID := 9036


func _mk_beast() -> CardData:
	var c := CardData.new()
	c.id = BEAST_ID
	c.card_name = "野兽之心"
	c.kind = "效果"
	c.cost = 1
	c.rarity = 2
	c.value = 2
	c.traits = ["野性"]
	return c


func _mk_ally() -> CardData:
	var c := CardData.new()
	c.id = 8003
	c.card_name = "农民"
	c.kind = "盟友"
	c.cost = 3
	c.power = 3
	c.health = 8
	c.attack_range = 1
	c.move_speed = 1
	return c


func _mk_foe() -> CardData:
	var c := CardData.new()
	c.id = 9001
	c.card_name = "鸭子骑士"
	c.kind = "盟友"
	c.cost = 6
	c.power = 5
	c.health = 30
	c.attack_range = 1
	c.move_speed = 1
	return c


func _run(n: int) -> void:
	var st := FieldState.new([], 20, 20, -1, "探针", false)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	eng.start_game(1)
	var hand: Array[CardData] = []
	for _i in n:
		hand.append(_mk_beast())
	eng.state.hand = hand
	eng.state.energy = 5
	for _j in n:
		eng.use_effect(0)
	print("[n=%d] effects.size=%d" % [n, eng.state.effects.size()])
	print("       _ally_dmg_bonus=%d  _beast_hp_bonus=%d  (期望 %d / %d)" % [
		eng._ally_dmg_bonus(_mk_ally(), GameEngine.SIDE_SELF),
		eng._beast_hp_bonus(_mk_ally()), n, 2 * n])

	eng.state.hand = [_mk_ally()]
	eng.state.energy = 5
	eng.play_from_hand(0, Vector2i(4, 0))
	var p: Placement = eng.state.unit_at(Vector2i(4, 0))
	print("       落地盟友 health=%d  (基础8, 期望 8+2*%d=%d)" % [
		p.health, n, 8 + 2 * n])

	eng.state.place(_mk_foe(), Vector2i(3, 0), "opponent")
	eng.attack(Vector2i(4, 0), Vector2i(3, 0))
	var q: Placement = eng.state.unit_at(Vector2i(3, 0))
	print("       敌方被打后 health=%d  (基础30, 期望 30-(3+%d)=%d)" % [
		q.health, n, 30 - (3 + n)])


func _check_card_text() -> void:
	## R617：卡面补「可叠加。」后，确认显示层清洗口不会把它一并剥掉。
	var raw := FileAccess.get_file_as_string("res://cards.json")
	var j: Variant = JSON.parse_string(raw)
	var arr: Array = j["cards"] if j is Dictionary and j.has("cards") else j
	for d in arr:
		if int(d["id"]) == BEAST_ID:
			var src: String = str(d["effect_text"])
			var shown: String = CardText.clean_meta_notes(src)
			print("[text] raw   = %s" % src)
			print("[text] shown = %s" % shown)
			print("[text] 可叠加可见 = %s" % str(shown.contains("可叠加")))
			return
	print("[text] 未找到 9036")


func _init() -> void:
	for n in [1, 2, 3]:
		_run(n)
	_check_card_text()
	quit(0)
