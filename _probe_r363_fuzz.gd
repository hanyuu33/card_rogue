extends SceneTree
## 探针（R363，临时）：把「龙族巢穴」整场跑一遍（真 AI + 随机玩家动作），
## 每一步对账一件事：**场上 9028（龙裔）的张数 == 已经死掉的幼龙张数**。
## 只要有一只幼龙没死却变成龙裔，这里就会红。

var _fails := 0

func _ck(name: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("  FAIL ", name)


func _count_id(st: FieldState, id: int) -> int:
	var n := 0
	for cell: Vector2i in st.board.keys():
		var p: Placement = st.unit_at(cell)
		if p != null and p.card.id == id:
			n += 1
	return n


func _board(st: FieldState) -> String:
	var out: Array[String] = []
	var keys: Array[Vector2i] = []
	for c: Vector2i in st.board.keys():
		keys.append(c)
	keys.sort()
	for c: Vector2i in keys:
		out.append("%s=%s" % [str(c), st.unit_at(c).card.card_name])
	return " | ".join(out)


func _init() -> void:
	ProfileData.set_test_mode()
	var repo := CardRepo.load_json()
	var lvl: Dictionary = GameLevels._dragon_nest()
	var deck: Array[CardData] = repo.starter_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024
	var st := FieldState.new(deck, 20, 30, -1, "龙族巢穴", true, rng)
	var e := GameEngine.new(st)
	e.start_game(int(lvl.get("player_hp", 20)), int(lvl.get("enemy_hp", 30)), true)
	for en: Array in lvl["enemy_units"]:
		st.place(repo.get_card(int(en[0])), en[6], GameEngine.SIDE_OPPONENT)
	e.configure_growth(lvl.get("enemy_growth", {}))

	var whelps_dead := 0
	var killed_whelp_cells: Array[Vector2i] = []

	for step in 60:
		# 玩家侧：随机给敌方幼龙来一发（模拟「打掉一只」），再看对账
		var targets: Array[Vector2i] = []
		for cell: Vector2i in st.board.keys():
			var p: Placement = st.unit_at(cell)
			if p != null and p.owner == GameEngine.SIDE_OPPONENT and p.card.id == 1014:
				targets.append(cell)
		if not targets.is_empty():
			var tgt: Vector2i = targets[rng.randi_range(0, targets.size() - 1)]
			e.damage_cell(tgt, 99, "探针")
			e._destroy_dead()
			e.flush_all_death_effects()
			if st.unit_at(tgt) == null or st.unit_at(tgt).card.id != 1014:
				whelps_dead += 1
				killed_whelp_cells.append(tgt)
		var n9028 := _count_id(st, 9028)
		if n9028 != whelps_dead:
			print("  ✗ 第 %d 步对不上：龙裔 %d 张 / 死掉幼龙 %d 只" % [step, n9028, whelps_dead])
			print("    棋盘：", _board(st))
		_ck("第 %d 步：龙裔张数 == 死掉幼龙数（%d vs %d）" % [step, n9028, whelps_dead],
				n9028 == whelps_dead)
		# 剩下来的幼龙必须是「原本就在的」—— 检查它们的格子没被龙裔占
		for cell: Vector2i in st.board.keys():
			var p2: Placement = st.unit_at(cell)
			if p2 != null and p2.card.id == 1014:
				_ck("第 %d 步：幼龙不会自己变成龙裔（%s）" % [step, str(cell)],
						not killed_whelp_cells.has(cell))
		# 过一个回合，让真 AI 也参与（AI 会打我们 / 移动幼龙）
		e.end_turn()
		e.flush_all_death_effects()
		if st.hp_self <= 0 or _count_id(st, 1014) + _count_id(st, 1013) == 0:
			break

	print("终局棋盘：", _board(st))
	print("=== 探针结束：%d 项失败 ===" % _fails)
	quit(1 if _fails > 0 else 0)
