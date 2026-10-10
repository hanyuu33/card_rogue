extends SceneTree
## headless 录像系统测试（R46）：godot --headless -s scripts/test_replay.gd
## 覆盖：
##   1. 参数编码（Vector2i ↔ JSON）
##   2. 录像文件落盘 → 列表 → 载入回放 → 条目消费（take/peek/advance）
##   3. run 层随机可复现（同种子 → 同地图 / 同道具三选一 / 同关卡抽取链）
##   4. 牌库洗牌可复现（FieldState 注入 RNG）
##   5. 战斗整体可复现（同种子 + 同玩家动作 → 最终局面快照一致；两次模拟互证）

var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		fails += 1
		printerr("  ✗ ", msg)


func _init() -> void:
	print("== 录像系统测试（R46） ==")
	_test_encoding()
	_test_record_roundtrip()
	_test_run_rng_reproducible()
	_test_shuffle_reproducible()
	_test_battle_reproducible()
	print("== 录像系统测试完成：%s ==" % ("有失败" if fails > 0 else "全部通过"))
	quit(1 if fails > 0 else 0)


# ──────────────────────────── 1. 参数编码 ────────────────────────────

func _test_encoding() -> void:
	var e: Variant = ReplayLog._enc(Vector2i(3, 4))
	check(e is Array and (e as Array).size() == 2
			and int((e as Array)[0]) == 3 and int((e as Array)[1]) == 4,
			"Vector2i → [x, y]")
	check(ReplayLog.vec([3, 4]) == Vector2i(3, 4), "[x, y] → Vector2i")
	check(ReplayLog.vec_or_null(null) == null, "null 目标保持 null")
	check(ReplayLog.vec_or_null([1, 2]) == Vector2i(1, 2), "[x, y] 目标还原")
	var nested: Variant = ReplayLog._enc([Vector2i(1, 1), {"c": Vector2i(2, 2)}])
	var s := JSON.stringify(nested)
	check(s == "[[1,1],{\"c\":[2,2]}]", "嵌套参数 JSON 化（%s）" % s)


# ──────────────────────────── 2. 录制 ↔ 回放往返 ────────────────────────────

func _test_record_roundtrip() -> void:
	var before := ReplayLog.list_replays().size()
	RunState.run_seed = 20261002
	ReplayLog.begin_run("暗影刺客")
	check(ReplayLog.recording, "begin_run 进入录制")
	ReplayLog.ev("relic_pick", {"id": 6003})
	ReplayLog.ev("map", {"node": 17})
	ReplayLog.act("play_from_hand", [2, Vector2i(1, 1)])
	ReplayLog.ev("battle_begin", {"seed": 999})
	ReplayLog.act("use_spell", [0, null])
	ReplayLog.ev("battle_end", {"win": true, "hp": 41})
	ReplayLog.finish("win")
	check(not ReplayLog.recording, "finish 落盘并停止录制")
	var items := ReplayLog.list_replays()
	check(items.size() == before + 1, "列表 +1（%d → %d）" % [before, items.size()])
	var meta: Dictionary = items[0]["meta"]
	check(str(meta.get("result", "")) == "win", "meta 结果 = win")
	check(int(meta.get("battles", 0)) == 1, "meta 战斗数 = 1")
	check(int(meta.get("run_seed", 0)) == 20261002, "meta 记录 run 种子")
	# 回放：逐条消费
	check(ReplayLog.start_playback(str(items[0]["path"])).size() > 0, "start_playback 载入")
	var e1 := ReplayLog.take("relic_pick")
	check(int(e1.get("id", 0)) == 6003, "take(relic_pick) = 6003")
	var e2 := ReplayLog.take("map")
	check(int(e2.get("node", 0)) == 17, "take(map) = 17")
	ReplayLog.advance()   # 手动消费 act（peek 后执行）
	var p := ReplayLog.peek()
	check(str(p.get("k", "")) == "battle_begin", "peek 下一条 = battle_begin")
	var eb := ReplayLog.take("battle_begin")
	check(int(eb.get("seed", 0)) == 999, "battle_begin 携带战斗种子")
	var es := ReplayLog.peek()
	check(str(es.get("f", "")) == "use_spell", "peek 下一条 = use_spell（技能 act）")
	ReplayLog.advance()
	var ee := ReplayLog.take("battle_end")
	check(bool(ee.get("win", false)) and int(ee.get("hp", 0)) == 41,
			"take(battle_end) 携带胜负与血量")
	check(ReplayLog.take("run_end").get("result", "") == "win", "run_end 收尾")
	# 乱序消费 → 停止回放兜底
	if ReplayLog.playing:
		ReplayLog.take("relic_pick")   # 此时下一条不是它 → 停止
	check(not ReplayLog.playing, "类型失配 → 自动停止回放")
	# 清理测试录像
	for it in ReplayLog.list_replays():
		if int(it["meta"].get("run_seed", 0)) == 20261002 \
				and str(it["meta"].get("class", "")) == "暗影刺客":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(it["path"])))
	check(ReplayLog.list_replays().size() == before, "测试录像已清理")


# ──────────────────────────── 3. run 层随机可复现 ────────────────────────────

func _map_sig(cards: Array) -> String:
	## 地图结构签名：id/坐标/类型/是否「?」房/门（与绘制无关的字段剔除）。
	## R128：5×7 格子地图 —— 每格独立成项（不再分层嵌套）。
	var out := []
	for c: Dictionary in cards:
		out.append([int(c["id"]), int(c["col"]), int(c["row"]), str(c["type"]),
				bool(c.get("hidden", false)), str(c.get("event_kind", "")),
				(c["doors"] as Array).duplicate()])
	return JSON.stringify(out)


func _test_run_rng_reproducible() -> void:
	var r1 := RandomNumberGenerator.new()
	r1.seed = 424242
	var r2 := RandomNumberGenerator.new()
	r2.seed = 424242
	var m1 := RogueMap.generate(r1, GameLayers.LAYER_DEFAULT)
	var m2 := RogueMap.generate(r2, GameLayers.LAYER_DEFAULT)
	check(_map_sig(m1) == _map_sig(m2), "同种子 → 同一张地图（%d 格）"
			% [m1.size()])
	var m3 := RogueMap.generate(r1, GameLayers.LAYER_DEFAULT)
	check(_map_sig(m1) != _map_sig(m3), "不同随机状态 → 不同地图")
	# 道具三选一：直接驱动 run_rng 验证链条可复现
	RelicRepo.load_json()
	var old_layer := RunState.current_layer
	RunState.current_layer = GameLayers.LAYER_DEFAULT
	RunState.run_rng = RandomNumberGenerator.new()
	RunState.run_rng.seed = 777
	var c1: Array[int] = RunState._roll_relic_choice()
	RunState.run_rng = RandomNumberGenerator.new()
	RunState.run_rng.seed = 777
	var c2: Array[int] = RunState._roll_relic_choice()
	RunState.current_layer = old_layer
	check(c1 == c2, "同种子 → 同一组起始道具三选一")


# ──────────────────────────── 4. 牌库洗牌可复现 ────────────────────────────

func _deck_ids() -> Array[CardData]:
	var repo := CardRepo.load_json()
	var out: Array[CardData] = []
	for id in [8001, 8001, 8002, 8002, 8003, 8004, 9003, 9086]:
		var c := repo.get_card(id)
		if c != null:
			out.append(c)
	return out


func _test_shuffle_reproducible() -> void:
	var g1 := RandomNumberGenerator.new()
	g1.seed = 555
	var g2 := RandomNumberGenerator.new()
	g2.seed = 555
	var s1 := FieldState.new(_deck_ids(), 30, 30, -1, "t", true, g1)
	var s2 := FieldState.new(_deck_ids(), 30, 30, -1, "t", true, g2)
	var ids1 := []
	var ids2 := []
	for c: CardData in s1.deck:
		ids1.append(c.id)
	for c: CardData in s2.deck:
		ids2.append(c.id)
	check(JSON.stringify(ids1) == JSON.stringify(ids2),
			"同种子 → 牌库洗牌顺序一致")
	# 从洗过的牌堆里抽 3 张再洗（模拟弃牌回牌库）：仍一致
	for i in 3:
		s1.draw()
		s2.draw()
	s1._shuffle_deck()
	s2._shuffle_deck()
	var ids3 := []
	var ids4 := []
	for c: CardData in s1.deck:
		ids3.append(c.id)
	for c: CardData in s2.deck:
		ids4.append(c.id)
	check(JSON.stringify(ids3) == JSON.stringify(ids4), "二次洗牌仍一致")


# ──────────────────────────── 5. 战斗整体可复现 ────────────────────────────

func _board_sig(state: FieldState) -> String:
	## 全场快照：双方棋盘 + 手牌 + 牌库/弃牌规模 + 生命 + 回合 + 结果。
	var keys: Array = state.board.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	var cells := []
	for k: Vector2i in keys:
		var p: Placement = state.board[k]
		if p != null:
			cells.append([int(k.x), int(k.y), p.card.id,
					p.card.power - p.atk_debuff + p.atk_buff, p.health])
	var hand := []
	for c: CardData in state.hand:
		hand.append(c.id)
	return JSON.stringify([cells, hand, state.deck.size(), state.discard.size(),
			state.hp_self, state.hp_opponent])


func _sim_battle(seed: int) -> String:
	## 按固定「玩家策略」打一场战斗：能上手上第 0 张就上，否则结束回合；
	## AI 由引擎驱动（与战斗场景相同的调用序列）。
	var g := RandomNumberGenerator.new()
	g.seed = seed
	var state := FieldState.new(_deck_ids(), 30, 30, -1, "replay_t", true, g)
	var engine := GameEngine.new(state)
	engine.ai_enabled = true
	engine.rng.seed = seed
	engine.start_game(5)
	var guard := 0
	while not engine.over and guard < 200:
		guard += 1
		if engine.current_side != GameEngine.SIDE_SELF:
			# 对手回合：驱动 AI（战斗场景的等价调用）
			var q := engine.ai_action_queue()
			if q.is_empty():
				engine.end_turn()
			else:
				engine.run_ai_unit(q[0])
			continue
		if engine.can_play_from_hand(0) and engine.state.hand.size() > 0:
			var card := engine.state.hand[0]
			var done := false
			if card.kind == "技能":
				if engine.can_pay_card(card):
					engine.use_spell(0, null)
					done = true
			elif card.kind == "效果":
				if engine.can_pay_card(card):
					engine.use_effect(0)
					done = true
			else:
				for cell: Vector2i in [Vector2i(3, 1), Vector2i(3, 0), Vector2i(3, 2),
						Vector2i(4, 1), Vector2i(5, 1)]:
					if engine.state.board.get(cell) == null:
						engine.play_from_hand(0, cell)
						done = true
						break
			if done:
				continue
		engine.end_turn()
	return _board_sig(engine.state)


func _test_battle_reproducible() -> void:
	var a := _sim_battle(31337)
	var b := _sim_battle(31337)
	var c := _sim_battle(31338)
	check(a == b, "同种子 + 同动作 → 两场战斗最终局面完全一致")
	check(a != c, "不同种子 → 局面不同（随机确实生效）")
