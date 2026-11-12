extends SceneTree
## 只读探针：蓄力（9085）叠「下一张技能生效 2 次」时，**第二段**到底有没有实效果。
##
## 用法：
##   godot --headless --path . --script res://tools/probe_charge_second.gd
##
## 场景固定：己方 1 个单位在 (0,1)，敌方 3 个单位在 (3,1) / (1,2) / (2,3)，血量 400
## （打不死 → 排除「第二段因为目标已死而合理落空」这条噪音）。
## 每张卡跑两遍：
##   A 对照（无蓄力）：直接打一次，得基准 detail；
##   B 实验（有蓄力）：先打 9085，再打该卡 → 一次调用结算两段，detail = "蓄力 ×2 → 段1；段2"。
## 判定：B 里「没有目标 / 落空 / 已不在场上」的出现次数 > A 的次数 → 第二段白丢。

const GE = preload("res://scripts/game_engine.gd")
const FS = preload("res://scripts/field_state.gd")
const PL = preload("res://scripts/placement.gd")
const CardRepo = preload("res://scripts/card_repo.gd")

const TARGET_CELL := Vector2i(3, 1)
const FOE_CELLS: Array[Vector2i] = [Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 3)]
const BAD_WORDS: Array[String] = ["没有目标", "落空", "已不在场上", "没有敌人"]

var _ally_id := 0
var _foe_id := 0


func _initialize() -> void:
	printerr("[probe] init")
	_run.call_deferred()


func _mk(eng, card, cell: Vector2i, who: String, hp: int):
	var p = PL.new()
	p.card = card
	p.owner = who
	p.health = hp
	eng.state.board[cell] = p
	return p


func _build(repo):
	var st = FS.new([], 60, 400, -1, "", false)
	st.energy = 99
	st.opp_energy = 99
	var eng = GE.new(st)
	_mk(eng, repo.get_card(_ally_id), Vector2i(0, 1), "self", 30)
	for i in FOE_CELLS.size():
		_mk(eng, repo.get_card(_foe_id), FOE_CELLS[i], "opponent", 400)
	return eng


func _bad_hits(txt: String) -> int:
	var n := 0
	for w: String in BAD_WORDS:
		var at := 0
		while true:
			var found := txt.find(w, at)
			if found < 0:
				break
			n += 1
			at = found + w.length()
	return n


func _played(eng) -> bool:
	for line: String in eng.log:
		if line.begins_with("使用技能"):
			return true
	return false


func _scan(repo, card) -> Dictionary:
	var tgt = null
	if card.target_mode == "unit" or card.target_mode == "cell":
		tgt = TARGET_CELL
	# A 对照：无蓄力
	var ea = _build(repo)
	ea.state.hand.append(repo.get_card(card.id))
	var da: String = ea.use_spell(0, tgt)
	var played_a := _played(ea)
	# B 实验：先蓄力
	var eb = _build(repo)
	eb.state.hand.append(repo.get_card(9085))
	eb.state.hand.append(repo.get_card(card.id))
	var pre: String = eb.use_spell(0, null)
	var db: String = eb.use_spell(0, tgt)
	var played_b := _played(eb)
	return {
		"id": card.id, "name": card.card_name, "mode": card.target_mode,
		"played": played_a and played_b, "charge": pre,
		"d1": da, "d2": db,
		"bad_a": _bad_hits(da), "bad_b": _bad_hits(db),
	}


func _run() -> void:
	printerr("[probe] run start")
	var repo := CardRepo.load_json()
	printerr("[probe] repo loaded")
	for c: CardData in repo.all_cards():
		if _ally_id == 0 and c.kind == "盟友" and c.group == "player":
			_ally_id = c.id
		if _foe_id == 0 and c.kind == "盟友" and c.group == "enemy":
			_foe_id = c.id
	if _ally_id == 0 or _foe_id == 0:
		print("PROBE ERROR 占位单位找不到")
		quit()
		return
	print("# ally=%d foe=%d" % [_ally_id, _foe_id])

	var rows: Array = []
	for c2: CardData in repo.all_cards():
		if c2.kind != "技能" or c2.group != "player":
			continue
		if c2.target_mode == "hand_unit" or c2.target_mode == "hand_any":
			continue
		printerr("[scan] %d %s" % [c2.id, c2.card_name])
		rows.append(_scan(repo, c2))

	var bad := 0
	for r: Dictionary in rows:
		if not bool(r["played"]):
			print("SKIP %d %s｜未进入结算（%s）" % [r["id"], r["name"], r["d1"]])
			continue
		var worse: bool = int(r["bad_b"]) > int(r["bad_a"])
		if worse:
			bad += 1
		print("%s %d %s [%s]｜对照=%s｜蓄力版=%s" % [
			("!! 第二段白丢" if worse else "ok"), r["id"], r["name"],
			r["mode"], r["d1"], r["d2"]])
	print("PROBE DONE 卡片 %d 张，第二段白丢 %d 张" % [rows.size(), bad])
	quit()
