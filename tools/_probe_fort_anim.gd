extends SceneTree
## 临时探针（R869）：验证失控要塞「立卡」用的界面分组逻辑。
## 检查三件事，每一条都是「玩家看到的顺序对不对」的硬条件：
##   ① begin → 收尾之间的事件能被完整缓冲；
##   ② 分成几组 = 引擎实际放出来几张（`fort_casts.size()`）；
##   ③ 每组都有 `spell` 事件（没有的那组就是落空卡，界面整组丢掉，不会立空壳）。

var _buf: Array = []
var _buffering := false
var _begin_n := 0
var _end_n := 0


func _init() -> void:
	var bad := 0
	for seed_i in range(1, 31):
		var msg := _run(seed_i)
		if msg != "":
			bad += 1
			print("X seed=%d %s" % [seed_i, msg])
	if bad == 0:
		print("OK 30 个种子：缓冲 / 分组 / 落空剔除 全部正确")
	else:
		print("FAIL %d / 30" % bad)
	quit(1 if bad > 0 else 0)


func _on_act(kind: String, data: Dictionary) -> void:
	if _buffering:
		if kind != "out_of_control_fort":
			_buf.append({"kind": kind, "data": data})
			return
		_buffering = false
	elif kind == "out_of_control_fort_begin":
		_buffering = true
		_begin_n += 1
	if kind == "out_of_control_fort":
		_end_n += 1


func _run(seed_i: int) -> String:
	_buf.clear()
	_buffering = false
	_begin_n = 0
	_end_n = 0
	var repo := CardRepo.load_json()
	var deck: Array[CardData] = []
	for i in 10:
		deck.append(CardData.from_dict(repo.get_card(9161).to_dict()))
	var st := FieldState.new(deck, 20, 20, -1, "探针", true)
	var eng := GameEngine.new(st)
	eng.ai_enabled = false
	eng.rng.seed = seed_i
	eng.action.connect(_on_act)
	eng.start_game()
	eng.state.energy = 20
	eng.state.self_card_changes = 5
	eng.state.hand.clear()
	eng.state.hand.append(CardData.from_dict(repo.get_card(9161).to_dict()))
	eng.state.hand.append(CardData.from_dict(repo.get_card(8029).to_dict()))
	eng.play_from_hand(0, Vector2i(5, 0))
	if _begin_n != 1 or _end_n != 1:
		return "begin=%d 收尾=%d（应当各 1 次）" % [_begin_n, _end_n]
	# 按界面同一套逻辑分组
	var groups: Array = []
	var cur: Dictionary = {}
	for ev: Dictionary in _buf:
		if str(ev.get("kind", "")) == "fort_cast_announce":
			cur = {"name": str((ev["data"] as Dictionary).get("name", "")), "events": []}
			groups.append(cur)
		elif not cur.is_empty():
			(cur["events"] as Array).append(ev)
	var kept: Array = []
	var dropped: Array = []
	for g: Dictionary in groups:
		var ok := false
		for ev2: Dictionary in (g["events"] as Array):
			if str(ev2.get("kind", "")) == "fort_cast_result":
				ok = bool((ev2["data"] as Dictionary).get("ok", false))
				break
		if ok:
			kept.append(g)
		else:
			dropped.append(g["name"])
	if kept.size() != eng.fort_casts.size():
		return "分组 %d != fort_casts %d（落空组 %s）" % [
				kept.size(), eng.fort_casts.size(), str(dropped)]
	for i in kept.size():
		if str(kept[i]["name"]) != eng.fort_casts[i]:
			return "第 %d 组是「%s」，引擎记录是「%s」" % [
					i + 1, str(kept[i]["name"]), eng.fort_casts[i]]
	# 淘汰 9174 的选牌页必须被就地收掉 —— 否则立卡演完、界面上还杵着一个选卡页。
	if eng.eliminate_pending:
		return "淘汰 9174 的选卡页没收掉（eliminate_pending 仍为 true）"
	return ""
