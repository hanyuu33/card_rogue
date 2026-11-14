extends SceneTree
## R705 排查：灵魂收割者（9233）的「费用本局 -1」到底减到了哪里。
##
## 用法（headless）：
##   Godot_v4.3-stable_win64_console.exe --headless --path . --script res://tools/_r705_reaper.gd
##
## 走的是**真实出牌路径** `play_from_hand`（不是 `state.place` 直接摆），
## 因为 R504 的现有测试只断言 `state.card_discount` 里记了数，从没验过
## 「读出来的费用真的降了」——这一步正是本次要查的缺口。

var _fails := 0


func _initialize() -> void:
	ProfileData.set_test_mode()
	RunState.end_run()
	_run()
	print("== R705 结果：%s ==" % ("全部通过" if _fails == 0 else "%d 项失败" % _fails))
	quit(1 if _fails > 0 else 0)


func _ck(ok: bool, msg: String) -> void:
	if ok:
		print("  ✓ ", msg)
	else:
		_fails += 1
		print("  ✗ ", msg)


func _repo() -> CardRepo:
	return CardRepo.load_json()


func _engine(hand_ids: Array) -> GameEngine:
	var repo := _repo()
	var deck: Array[CardData] = []
	for i in 30:
		deck.append(CardData.from_dict(repo.get_card(8002).to_dict()))
	var st := FieldState.new(deck, 60, 60, -1, "测试", false)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	eng.start_game(1)
	st.hand.clear()
	for id: int in hand_ids:
		st.hand.append(CardData.from_dict(repo.get_card(id).to_dict()))
	return eng


func _run() -> void:
	_case_real_play()
	_case_hand_cost_after_mark()
	_case_replay_same_instance()


func _case_real_play() -> void:
	print("[1] 真实出牌：放标记 → 打灵魂收割者 → 打被标记的敌人")
	var repo := _repo()
	var eng := _engine([9224, 9233])
	var st := eng.state

	var mark_card: CardData = st.hand[0]
	var reaper_card: CardData = st.hand[1]
	var cost_before := eng.cost_of(reaper_card)
	_ck(cost_before == 8, "打出前 9233 费用 = 8（实际 %d）" % cost_before)

	st.energy = 20
	var pf := eng.play_from_hand(0, Vector2i(3, 1))
	_ck(st.has_mark(), "标记 9224 已铺在 %s（has_mark=%s）" % [
			str(st.mark_cell()), str(st.has_mark())])

	var p := eng.play_from_hand(0, Vector2i(4, 1))
	_ck(p != null and p.card.id == 9233, "灵魂收割者落场（%s）" % [
			"OK" if p != null else "null"])
	if p == null:
		return
	_ck(p.card == reaper_card, "场上单位复用**手牌那张**实例（同一引用）")

	# 敌人站在标记格上
	var foe: Placement = st.place(CardData.from_dict(repo.get_card(1051).to_dict()),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	foe.health = 60

	eng.attack(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)

	var disc := int(st.card_discount.get(p.card, 0))
	print("     card_discount[单位.card] = %d" % disc)
	print("     cost_of(单位.card) = %d" % eng.cost_of(p.card))
	print("     cost_of(卡的引用是否同一实例) = %s" % str(p.card == reaper_card))
	_ck(disc == 1, "打中被标记敌人 → 记账 -1（实际 %d）" % disc)

	# 关键：同一个实例、走 cost_of 之后，到底降到几费？
	var after := eng.cost_of(p.card)
	_ck(after == 7, "cost_of 真的降到 7（实际 %d）" % after)

	# 单位还在场上 —— 玩家在**任何界面**都读不到它的费用
	var in_hand := st.hand.has(p.card)
	_ck(not in_hand, "单位在场、已离手（手牌里没有这张：%s）" % str(in_hand))


func _case_hand_cost_after_mark() -> void:
	print("[2] 同一实例回手后再看费用（模拟思想钢印那条路）")
	var repo := _repo()
	var eng := _engine([9224, 9233])
	var st := eng.state
	st.energy = 20
	eng.play_from_hand(0, Vector2i(3, 1))
	var p := eng.play_from_hand(0, Vector2i(4, 1))
	if p == null:
		_ck(false, "落场失败，跳过")
		return
	var foe: Placement = st.place(CardData.from_dict(repo.get_card(1051).to_dict()),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	foe.health = 60
	eng.attack(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)

	# 回手：与 `_destroy` 里 `state.hand.append(p.card)` 完全同一句
	st.hand.append(p.card)
	var c_hand := eng.cost_of(p.card)
	_ck(c_hand == 7, "回到手牌里 → cost_of = 7（实际 %d）" % c_hand)


func _case_replay_same_instance() -> void:
	print("[3] 回手后再打出一次，减费还在不在")
	var repo := _repo()
	var eng := _engine([9224, 9233])
	var st := eng.state
	st.energy = 20
	eng.play_from_hand(0, Vector2i(3, 1))
	var p := eng.play_from_hand(0, Vector2i(4, 1))
	if p == null:
		return
	var foe: Placement = st.place(CardData.from_dict(repo.get_card(1051).to_dict()),
			Vector2i(3, 1), GameEngine.SIDE_OPPONENT)
	foe.health = 60
	eng.attack(Vector2i(4, 1), Vector2i(3, 1), GameEngine.SIDE_SELF)

	# 把单位收回手再打出（真实路径：手牌 index 0）
	st.board.erase(Vector2i(4, 1))
	st.hand.append(p.card)
	var c1 := eng.cost_of(p.card)
	var p2 := eng.play_from_hand(0, Vector2i(4, 1))
	_ck(p2 != null, "回手后能再次打出")
	if p2 == null:
		return
	_ck(p2.card == p.card, "二次落场仍是同一实例（%s）" % str(p2.card == p.card))
	var c2 := eng.cost_of(p2.card)
	_ck(c1 == 7 and c2 == 7, "两次读到的费用都是 7（%d / %d）" % [c1, c2])
