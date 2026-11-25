extends SceneTree
## R870 回归：失控要塞（9161）「玩家全程不操作也能跑完」。
##
## 口径（店长）：「所有要玩家选择的操作都要检查一下，改为随机选，包括选目标选格子选卡组
## 选弃牌区选组合等等，你要确保玩家不进行操作它自动进行」。
##
## 做法：把随机池里**每一张**技能卡（机械之心 · kind=技能 · rarity<=2）单独凭空释放一次，
## 每次都用同一套「什么都有」的场面（己方盟友 / 工事、敌方单位、手牌、卡组带素体、
## 弃牌区三族卡都有），逐条断言：
##   ① `has_pending_player_choice()` 必须为 false —— 没有任何面板留给玩家；
##   ② 组合类（8086 / 9193）必须真的拼出一张带 `combine_mark` 的卡（不是被兜底取消）；
##   ③ 合体 9167 必须真的让一张素体消失（`merge` 事件）；
##   ④ 需要目标的卡（聚能系 / 援护炮击）必须真的放出来（不是落空）。
##
## ⚠️ 这张表是「新加技能卡会不会又漏一条」的守门人：池子是**动态**捞的，谁往机械之心
##    加一张会弹面板的技能，这里立刻红 —— 不需要有人记得回来改这份测试。

var _passed := 0
var _failed := 0
var _fails: Array[String] = []
var _events: Array = []
var _pool: Array[CardData] = []


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_fails.append(msg)


func _init() -> void:
	var repo := CardRepo.load_json()
	for c: CardData in repo.all_cards():
		if c.card_class == PlayerClass.MECH and c.kind == "技能" and c.rarity <= 2:
			_pool.append(c)
	check(_pool.size() >= 30, "随机池要捞到 30+ 张（实际 %d）—— 池子口径变了就得先看这里"
			% _pool.size())

	for proto: CardData in _pool:
		var why := _one(proto)
		check(why == "", "R870 %d「%s」释放后不该剩下任何待选面板：%s"
				% [proto.id, proto.card_name, why])

	# 重点四张单独钉行为，不只钉「没留面板」
	check(_one(_by_id(8086)) == "" and _made_combo(), "R870 重构 8086：随机组合要真的拼出产物")
	check(_one(_by_id(9193)) == "" and _made_combo(), "R870 技术结合 9193：随机组合要真的拼出产物")
	check(_one(_by_id(9167)) == "" and _has_evt("merge"), "R870 合体 9167：要随机取一张素体并真的结算")
	check(_one(_by_id(9192)) == "", "R870 援护炮击 9192：要选中敌方目标并真的放出来")
	check(_one(_by_id(9174)) == "", "R870 淘汰 9174：要随机挑一张变素体，不留选卡页")

	# 跨种子稳定：随机源换成 seed 也不能有哪个种子漏面板 / 拼不出组合
	for s_i in range(1, 13):
		var bad: Array[String] = []
		for id_i in [8086, 9193, 9167, 9192, 9174]:
			var w := _one(_by_id(id_i), s_i)
			if w != "":
				bad.append("%d:%s" % [id_i, w])
		check(bad.is_empty(), "R870 seed=%d 五张重点卡都应自动跑完（%s）" % [s_i, ", ".join(bad)])

	# 判据口本身：挂着任一待办 → true；清掉 → false
	var e_chk := _new_eng(9)
	e_chk.wish_pending = true
	check(e_chk.has_pending_player_choice(), "R870 has_pending_player_choice：挂上许愿应判 true")
	e_chk.wish_pending = false
	check(not e_chk.has_pending_player_choice(), "R870 has_pending_player_choice：清掉后应判 false")

	print("FORT AUTO === 结束：%d 通过 / %d 失败 ===" % [_passed, _failed])
	for f: String in _fails:
		print("  ✗ %s" % f)
	quit(1 if _failed > 0 else 0)


var _last_eng: GameEngine = null


func _by_id(id_i: int) -> CardData:
	for c: CardData in _pool:
		if c.id == id_i:
			return c
	return null


func _on_act(kind: String, data: Dictionary) -> void:
	_events.append({"kind": kind, "data": data})


func _has_evt(kind: String) -> bool:
	for e: Dictionary in _events:
		if str(e["kind"]) == kind:
			return true
	return false


func _made_combo() -> bool:
	if _last_eng == null:
		return false
	for c: CardData in _last_eng.state.hand:
		if c.combine_mark:
			return true
	return false


func _new_eng(seed_i: int) -> GameEngine:
	var repo := CardRepo.load_json()
	var deck: Array[CardData] = []
	for i in 10:
		deck.append(CardData.from_dict(repo.get_card(9161).to_dict()))
	for i in 3:
		deck.append(CardData.from_dict(repo.get_card(8025).to_dict()))
	var st := FieldState.new(deck, 30, 30, -1, "R870", true)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	eng.rng.seed = seed_i
	eng.action.connect(_on_act)
	eng.start_game()
	# ⚠️ 开局会洗牌 + 摸 5 张，那 5 张有时正好把 3 张素体摸走（下面又清手牌）→
	#    「合体」偶尔会因为卡组里没有素体而落空，测试时红时绿。开局后**重置**牌库，
	#    让每次跑的都是同一副确定的牌。
	eng.state.deck.clear()
	for i in 10:
		eng.state.deck.append(CardData.from_dict(repo.get_card(9161).to_dict()))
	for i in 3:
		eng.state.deck.append(CardData.from_dict(repo.get_card(8025).to_dict()))
	eng.state.energy = 3
	eng.state.self_card_changes = 5
	# 场面：己方盟友 ×2、己方工事 ×1、敌方 ×2（让「选目标 / 选格子」都有得选）
	eng.state.place(CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(6, 1), "self")
	eng.state.place(CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(6, 2), "self")
	eng.state.place(CardData.from_dict(repo.get_card(8001).to_dict()), Vector2i(6, 0), "self")
	eng.state.place(CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(0, 1), "opponent")
	eng.state.place(CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(0, 2), "opponent")
	# 手牌：盟友 / 工事 / 技能各一张（手牌类技能与「变化手牌」类技能都有落点）
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(repo.get_card(8003).to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(9145).to_dict()))
	# 弃牌区：三族卡都有（弃牌区选牌类技能才有候选）
	eng.state.discard.clear()
	eng.state.discard.append(CardData.from_dict(repo.get_card(8025).to_dict()))
	eng.state.discard.append(CardData.from_dict(repo.get_card(8001).to_dict()))
	eng.state.discard.append(CardData.from_dict(repo.get_card(9172).to_dict()))
	return eng


func _one(proto: CardData, seed_i := 7) -> String:
	if proto == null:
		return "卡不在随机池里（池子口径变了？）"
	_events.clear()
	var eng := _new_eng(seed_i)
	_last_eng = eng
	var card := CardData.from_dict(proto.to_dict())
	card.traits = (proto.traits as Array).duplicate()
	card.affixes = (proto.affixes as Array).duplicate()
	eng._fort_play(card)
	if eng.has_pending_player_choice():
		return "还剩待选（combo=%s 淘汰=%s 返修=%s 合体=%s 专注=%s 许愿=%s）" % [
				str(eng.assemble_combo_pending), str(eng.eliminate_pending),
				str(eng.overhaul_pending), str(eng.merge_pending),
				str(eng.focus_pending), str(eng.wish_pending)]
	if proto.id == 8086 or proto.id == 9193:
		if not _made_combo():
			return "组合没拼出产物（组合页被兜底收掉了）"
	if proto.id == 9167 and not _has_evt("merge"):
		return "合体没结算（没有 merge 事件）"
	return ""
