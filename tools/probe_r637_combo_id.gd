extends SceneTree
## R637 探针（只读）：确认「组合产物不再继承属性槽原卡的效果」。
##   ① build 后的产物：id = 0、art_id = 属性槽原 id、卡图仍取得到、traits / 效果字段全空
##   ② 实战行为：赤狐 9034 当属性槽 → 产物上场**不再**从牌库抽技能牌
## 用法：godot --headless --path . --script res://tools/probe_r637_combo_id.gd
const Rules = preload("res://scripts/assemble_rules.gd")
const CardRepo = preload("res://scripts/card_repo.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("[FAIL] " + msg)
	else:
		print("[ok] " + msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var repo := CardRepo.load_json()
	var fox: CardData = repo.get_card(9034)
	var tiger: CardData = repo.get_card(9038)
	var hare: CardData = repo.get_card(9032)

	var prod := Rules.build(fox, tiger.upper_effect, hare.lower_effect, false)
	check(prod != null, "build 出产物")
	check(prod.id == 0, "产物 id = 0（不再命中母卡 id 特判），实际 %d" % prod.id)
	check(prod.art_id == 9034, "产物 art_id = 属性槽原 id 9034，实际 %d" % prod.art_id)
	check(prod.pic_id() == 9034, "pic_id() 回落 art_id = 9034，实际 %d" % prod.pic_id())
	check(CardFace.art_for(prod.pic_id()) != null, "卡图仍取得到")
	check(prod.card_name == "赤狐", "卡名沿用属性槽，实际 %s" % prod.card_name)
	check(prod.traits.is_empty(), "traits 清空，实际 %s" % str(prod.traits))
	check(prod.affixes.is_empty(), "affixes 清空，实际 %s" % str(prod.affixes))
	check(prod.trigger == "" and prod.combo_trigger == "" and prod.combo_scope == "",
			"扳机 / 组合钩子清空")
	check(prod.effect_text.find("从卡组随机抽取") < 0,
			"卡面不再写母卡效果，实际：%s" % prod.effect_text)

	# 序列化通道：复制 / 存档回来后仍然是「无 id 的产物」
	var copy := CardData.from_dict(prod.to_dict())
	check(copy.id == 0 and copy.art_id == 9034 and copy.traits.is_empty(),
			"to_dict → from_dict 通道不变形")
	# 老存档兜底：产物带着母卡 id 也要归零
	var legacy := prod.to_dict()
	legacy["id"] = 9034
	legacy.erase("art_id")
	var old_card := CardData.from_dict(legacy)
	check(old_card.id == 0 and old_card.art_id == 9034, "老存档里的产物读回来 id 归 0")

	# ② 实战：牌库里放技能牌，打出产物不该抽走
	var state := FieldState.new([], 20, 20, -1, "测试", false)
	var eng := GameEngine.new(state)
	eng.ai_enabled = false
	state.energy = 10
	for sid in [8002, 9083, 9077]:
		var sc: CardData = repo.get_card(sid)
		if sc != null:
			state.deck.append(CardData.from_dict(sc.to_dict()))
	state.hand.append(prod)
	var deck_before := state.deck.size()
	var played := eng.play_from_hand(0, Vector2i(4, 1))
	check(played != null, "产物能正常上场")
	check(state.deck.size() == deck_before,
			"产物上场后牌库没少（母卡赤狐的「抽一张技能牌」不再触发）：%d → %d"
			% [deck_before, state.deck.size()])

	# 对照：直接打出真赤狐 → 牌库必然少一张技能
	var state2 := FieldState.new([], 20, 20, -1, "测试", false)
	var eng2 := GameEngine.new(state2)
	eng2.ai_enabled = false
	state2.energy = 10
	for sid in [8002, 9083, 9077]:
		var sc2: CardData = repo.get_card(sid)
		if sc2 != null:
			state2.deck.append(CardData.from_dict(sc2.to_dict()))
	state2.hand.append(CardData.from_dict(fox.to_dict()))
	var d2 := state2.deck.size()
	var played2 := eng2.play_from_hand(0, Vector2i(4, 1))
	check(played2 != null, "赤狐本体能上场")
	check(state2.deck.size() == d2 - 1,
			"对照组：赤狐本体照旧抽走一张技能牌 %d → %d" % [d2, state2.deck.size()])

	print("PROBE_R637_RESULT fails=%d" % fails)
	quit()
