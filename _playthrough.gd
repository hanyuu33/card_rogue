extends SceneTree
## R46 后实机体验：自动通关驱动（逻辑层全真实代码路径）。
## 用法：godot --headless --path . -s res://_playthrough.gd -- --class=森林精魄 --seed=100 [--diff=0|1|2] [--boost]
## 输出：逐节点 trace + findings（异常/疑似 bug/失衡信号），JSON 打到 stdout 尾部。

const INFILTRATE_ID := 9100   # 潜入：两段施放（单独处理）

var repo: CardRepo
var findings: Array = []      # {kind, where, note}
var trace: Array = []         # 每场战斗/事件的摘要
var cls := "森林精魄"

func _f(kind: String, where: String, note: String) -> void:
	findings.append({"kind": kind, "where": where, "note": note})
	print("FINDING[%s] %s: %s" % [kind, where, note])

func _init() -> void:
	var sseed := 100
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--class="):
			cls = a.substr(8)
		elif a.begins_with("--seed="):
			sseed = int(a.substr(7))
		elif a.begins_with("--diff="):
			RunState.set_difficulty(int(a.substr(7)))   # 难度档位（R47）
	seed(sseed)   # start_run 里 run_seed = randi() 用全局随机 → 同种子可复现
	repo = CardRepo.load_json()
	var boost := false
	for a in OS.get_cmdline_user_args():
		if a == "--boost":
			boost = true
	print("=== PLAYTHROUGH class=%s seed=%d diff=%d boost=%s ===" % [cls, sseed,
			RunState.difficulty, boost])

	RunState.start_run([], GameLayers.LAYER_DEFAULT, cls)
	if boost:
		# 实验注入：模拟中后期强度（重伤害技能 + 成长盟友），用于体验二层/流程
		for cid in [9083, 9084, 9085, 9095, 9096, 9093, 9016, 9019]:
			RunState.deck_ids.append(cid)
			RunState.deck_ids.append(cid)
	print("run_seed=%d 初始卡组=%s 起始三选一=%s" % [RunState.run_seed,
			str(RunState.deck_ids), str(RunState.relic_choice)])
	# 起始道具：优先类固醇（+6 上限），其次鸡煲/栅栏修复术
	if not RunState.relic_choice.is_empty():
		var rid0 := RunState.relic_choice[0]
		for pref in [6001, 6003, 6021]:
			if RunState.relic_choice.has(pref):
				rid0 = pref
				break
		RunState.choose_start_relic(rid0)
		print("起始道具：%d" % rid0)
	var guard := 0
	while RunState.run_active and guard < 200:
		guard += 1
		var nodes := RunState.available_nodes()
		if nodes.is_empty():
			_f("flow", "地图", "available_nodes 为空但 run 未结束（疑似死路）")
			break
		var node: Dictionary = _pick_node(nodes)
		var nt := str(node["type"])
		var col := int(node.get("col", -1))
		print("--- 前进：%s(col=%d, kind=%s) hp=%d/%d deck=%d" % [nt, col,
				str(node.get("event_kind", "")), RunState.hp, RunState.max_hp,
				RunState.deck_ids.size()])
		_enter(node)
	print("=== RUN END: %s | 战斗记录 %d 场 ===" % [
			"通关" if _won else "未通关", RunState.battle_log.size()])
	print("TRACE_JSON_BEGIN")
	print(JSON.stringify({"class": cls, "seed": sseed, "won": _won,
			"findings": findings, "trace": trace}, "  "))
	print("TRACE_JSON_END")
	quit(0)

var _won := false

func _pick_node(nodes: Array) -> Dictionary:
	## 走法策略：优先普通战斗攒卡组 → 精英（血量健康时）→ 宝箱/事件 → 休息（血虚）→ Boss。
	var best: Dictionary = {}
	var best_score := -1.0
	for n: Dictionary in nodes:
		var nt := str(n["type"])
		var score := 0.0
		match nt:
			"battle":
				score = 5.0 if RunState.deck_ids.size() < 24 else 3.0
			"elite":
				score = 4.5 if (RunState.hp > RunState.max_hp * 0.65 \
						and RunState.deck_ids.size() >= 24) else -1.0
			"event":
				score = 3.5
			"chest":
				score = 4.0
			"rest":
				score = 4.8 if RunState.hp < RunState.max_hp * 0.7 else 1.0
			"boss":
				score = 0.5   # 最后走（地图上它本来就是终点）
		score += randf() * 0.1
		if score > best_score:
			best_score = score
			best = n
	return best

func _enter(node: Dictionary) -> void:
	var nt := str(node["type"])
	RunState.advance(int(node["id"]))
	match nt:
		"battle", "elite", "boss":
			_do_battle(node)
		"rest":
			if not RunState.has_relic(RunState.BARBECUE_RELIC_ID) \
					and RunState.hp > RunState.max_hp * 0.7:
				RunState.gain_relic(RunState.BARBECUE_RELIC_ID)
				trace.append({"node": "rest", "got": "烤肉"})
			else:
				var g := RunState.rest()
				trace.append({"node": "rest", "heal": g})
			RunState.complete_current()
		"chest":
			var rid := RunState.roll_reward_relic()
			if rid > 0:
				RunState.gain_relic(rid)
				trace.append({"node": "chest", "relic": rid})
			else:
				_f("flow", "宝箱层", "roll_reward_relic 返回 -1（池空）")
			RunState.complete_current()
		"event":
			_do_event(node)

func _do_event(node: Dictionary) -> void:
	var kind := str(node.get("event_kind", "treasure"))
	match kind:
		"monster":
			_do_battle(node)   # 地图场景同款：按普通战斗处理
		"treasure":
			RunState.reward_context = "event"
			RunState.reward_type = "normal"
			_take_card_reward()
			RunState.complete_current()
		"whisper":
			RunState.gain_relic(RunState.WHISPER_RELIC_ID)
			RunState.complete_current()
		"gaze":
			RunState.gain_relic(RunState.RICE_RELIC_ID)
			RunState.complete_current()
		"pear":
			RunState.gain_relic(RunState.PEAR_RELIC_ID)
			RunState.complete_current()
		"arcane":
			if not RunState.has_relic(RunState.ARCANE_CHARM_RELIC_ID):
				RunState.gain_relic(RunState.ARCANE_CHARM_RELIC_ID)
			else:
				RunState.reward_kinds = ["效果", "技能"]
				_take_card_reward()
				RunState.reward_kinds = []
			RunState.complete_current()
		"oblivion":
			# 删一张「木栅栏」以外的重复卡（简化：删最后一张非栅栏卡；没有就跳过）
			var idx := -1
			for i in RunState.deck_ids.size():
				if RunState.deck_ids[i] != 8001:
					idx = i   # 取最后一张非栅栏
			if idx >= 0 and RunState.deck_ids.size() > 13:
				RunState.delete_deck_card(idx)
				trace.append({"node": "oblivion", "deleted_idx": idx})
			RunState.complete_current()
		"bluefish":
			RunState.add_card(9050)
			RunState.complete_current()
		"hero":
			if RunState.can_trade_five(repo):
				var res := RunState.trade_five_for_one(repo)
				trace.append({"node": "hero", "ok": res["ok"],
						"removed": (res["removed"] as Array).size()})
			else:
				trace.append({"node": "hero", "ok": false})
			RunState.complete_current()
		"struggle":
			if RunState.hp > 21 + 10:
				RunState.take_damage(21)
				RunState.add_card(9018)
				trace.append({"node": "struggle", "took": true})
			else:
				trace.append({"node": "struggle", "took": false})
			RunState.complete_current()
		_:
			_f("flow", "事件", "未知事件 kind=%s" % kind)
			RunState.complete_current()

func _take_card_reward() -> void:
	## 与真实界面一致：roll 3 张选 1（这里按简单价值评估挑）。
	var rolled := CardReward.roll(repo, RunState.reward_type, CardReward.CHOICES,
			RunState.run_rng if RunState.run_active else null,
			RunState.reward_kinds)
	if rolled.is_empty():
		_f("flow", "卡牌奖励", "roll 返回空（kinds=%s）" % str(RunState.reward_kinds))
		return
	var best: CardData = rolled[0]
	var best_s := -1e9
	for c: CardData in rolled:
		var s := _card_value(c)
		if s > best_s:
			best_s = s
			best = c
	RunState.add_card(best.id)
	trace.append({"node": "reward", "card": best.id})

func _card_value(c: CardData) -> float:
	## 粗略价值：能打能扛的优先，费用是成本。
	match c.kind:
		"盟友":
			return c.power * 3.0 + c.health * 0.8 - c.cost + \
					(2.0 if c.move_speed >= 2 else 0.0)
		"技能":
			return 9.0 - c.cost * 0.5
		"效果":
			return 8.0 - c.cost * 0.5
		"工事":
			return 2.0
		_:
			return 1.0

# ------------------------------------------------------------ 战斗

func _do_battle(node: Dictionary) -> void:
	var lvl := RunState.next_level(node)
	if lvl.is_empty():
		_f("flow", "选关", "next_level 返回空（node=%s layer=%d）" % [
				str(node["type"]), RunState.node_layer(node)])
		RunState.complete_current()
		return
	var node_type := str(node["type"])
	var seed_b := RunState.run_rng.randi()
	var deck := RunState.build_deck(repo)
	var brng := RandomNumberGenerator.new()
	brng.seed = seed_b
	var state := FieldState.new(deck, RunState.hp, GameLevels.enemy_hp_of(lvl),
			int(lvl["turn_limit"]), str(lvl["name"]), bool(lvl["shuffle"]), brng)
	state.max_hp_self = RunState.max_hp
	var engine := GameEngine.new(state)
	engine.rng.seed = seed_b
	engine.self_relics = RunState.relics
	engine.duck_revive_chance = RunState.duck_revive_chance
	for e: Array in lvl["enemy_units"]:
		var card := CardData.new()
		var from_repo := repo.get_card(int(e[0]))
		if from_repo != null:
			card = from_repo
		else:
			card.id = int(e[0])
			card.card_name = str(e[1])
			card.kind = "盟友"
			card.cost = 1
			card.power = int(e[2])
			card.health = int(e[3])
			card.attack_range = int(e[4])
			card.move_speed = int(e[5])
		engine.state.place(card, e[6], GameEngine.SIDE_OPPONENT)
	engine.configure_growth(lvl.get("enemy_growth", {}))
	state.clear_win = not (lvl["enemy_units"] as Array).is_empty()
	var efx: Array[CardData] = []
	for eid in lvl.get("enemy_effects", []):
		var ec := repo.get_card(int(eid))
		if ec != null:
			efx.append(ec)
	engine.enable_enemy_effects(efx)
	engine.start_game(int(lvl["starting_hand"]))

	var turns := 0
	var guard := 0
	while not engine.over and guard < 800:
		guard += 1
		_resolve_pendings(engine)
		if engine.over:
			break
		if engine.current_side == GameEngine.SIDE_SELF:
			if turns != engine.turn_number:
				turns = engine.turn_number
			_resolve_pendings(engine)
			if not _try_play(engine) and not _units_step(engine):
				engine.end_turn()
		else:
			_drain_ai(engine)
	if not engine.over:
		_f("bug", "战斗[%s]" % str(lvl["name"]),
				"%d 次循环仍未结算（疑似软锁）" % guard)
		print("      current_side=%s turn=%d hp=%d/%d 敌HP=%d" % [
				engine.current_side, engine.turn_number, state.hp_self,
				state.max_hp_self, state.hp_opponent])
		var n0: int = engine.log.size()
		for li in range(maxi(0, n0 - 40), n0):
			print("      | %s" % engine.log[li])
	var win := engine.result == "胜利"
	for l in engine.log:
		print("      | %s" % l)   # 引擎日志（诊断用）
	# 写回（镜像 battle_scene._show_over）
	if win:
		engine.battle_end_heal()
		RunState.duck_revive_chance = engine.duck_revive_chance
		RunState.hp = maxi(0, engine.state.hp_self)
		RunState.max_hp = maxi(RunState.max_hp, engine.state.max_hp_self)
		RunState.heal(RunState.battle_win_heal())   # 难度 0：战斗胜利回 3 血（R47）
		RunState.on_battle_won(node_type)
		RunState.reward_type = "boss" if int(lvl.get("tier", -1)) == GameLevels.TIER_BOSS else "normal"
		var dropped := RunState.offer_relic_drop(node_type)
		if dropped > 0:
			RunState.claim_relic_drop()
		_take_card_reward()
		trace.append({"battle": str(lvl["name"]), "tier": int(lvl.get("tier", -1)),
				"type": node_type, "turns": turns, "win": true,
				"hp": RunState.hp, "deck": RunState.deck_ids.size()})
		print("    胜利 turns=%d hp=%d deck=%d" % [turns, RunState.hp, RunState.deck_ids.size()])
	else:
		RunState.record_battle(repo, str(lvl["name"]), int(lvl.get("tier", -1)),
				false, maxi(0, engine.state.hp_self))
		trace.append({"battle": str(lvl["name"]), "tier": int(lvl.get("tier", -1)),
				"type": node_type, "turns": turns, "win": false,
				"reason": engine.result_reason})
		print("    失败 turns=%d reason=%s" % [turns, engine.result_reason])
	if win and int(lvl.get("tier", -1)) == GameLevels.TIER_BOSS:
		var next_l := GameLayers.next_layer(RunState.current_layer)
		if next_l > 0:
			RunState.advance_layer(next_l)
			if not RunState.relic_choice.is_empty():
				RunState.choose_start_relic(RunState.relic_choice[0])
			print("    >>> 进入第 %d 层（满血，新三选一 %s）" % [next_l, str(RunState.relic_choice)])
		else:
			RunState.end_run()
			_won = true
			print("    >>> 通关！")
	elif not win:
		RunState.end_run()
	if win:
		RunState.complete_current()
		RunState.pending_node = {}

func _resolve_pendings(engine: GameEngine) -> void:
	## 镜像 UI 的待决面板：复活 / 鲸鱼 / 乌鸦 / 预判 / 拒绝命运。
	var guard := 0
	while guard < 20:
		guard += 1
		if engine.revive_pending:
			var opts := engine.revive_options()
			if opts.is_empty():
				_f("bug", "复活术", "revive_pending 但 revive_options 为空（真实游戏会卡面板）")
				break
			engine.revive_recall(opts[0])
			continue
		if engine.whale_pending:
			var wopts := engine.whale_options()
			if wopts.is_empty():
				_f("bug", "鲸鱼之怒", "whale_pending 但 options 为空")
				break
			engine.whale_pick(wopts[0])
			continue
		if engine.crow_pending:
			var copts := engine.crow_options()
			if copts.is_empty():
				_f("bug", "乌鸦回手", "crow_pending 但 options 为空")
				break
			engine.crow_recall(copts[0])
			continue
		if engine.foresight_pick:
			var fopts: Array[int] = []
			for i in engine.state.discard.size():
				var dc: CardData = engine.state.discard[i]
				if dc.cost == 0 and dc.kind == "技能":
					fopts.append(i)
			if fopts.is_empty():
				_f("flow", "预判", "弃牌区没有 0 费技能 → 走分支 2（随机非 0 费）")
				engine.foresight_choose(1)
			else:
				engine.foresight_pick_card(fopts[0])
			continue
		if engine.fate_pending:
			if engine.state.discard.is_empty():
				_f("bug", "拒绝命运", "fate_pending 但弃牌区为空（软锁候选）")
				break
			engine.fate_pick(engine.state.discard.size() - 1)
			continue
		break

func _try_play(engine: GameEngine) -> bool:
	## 出一张牌（带优先级：效果 → 技能 → 盟友 → 工事 → X 费最后——
	## 流星雨等 X 费会吃光全部能量，必须最后打）。
	var hand := engine.state.hand
	for pass_no in 5:
		for i in hand.size():
			var card: CardData = hand[i]
			var k := str(card.kind)
			if card.x_cost and pass_no < 4:
				continue
			match pass_no:
				0:
					if k != "效果":
						continue
				1:
					if k != "技能" or card.id == INFILTRATE_ID:
						continue
					if card.id == 9023:
						continue
				2:
					if k != "盟友":
						continue
				3:
					if k != "工事":
						continue
				4:
					if not card.x_cost:
						continue
			if not engine.can_play_from_hand(i):
				continue
			if card.id == INFILTRATE_ID:
				if _try_infiltrate(engine, i):
					return true
				continue
			match k:
				"盟友", "工事":
					var cell := _empty_own_cell(engine)
					if cell.x >= 0:
						engine.play_from_hand(i, cell)
						return true
				"技能":
					if card.id == 9023:
						# 英雄：弃 4 张才可上 —— 手牌够才打
						if hand.size() >= 5:
							var cell2 := _empty_own_cell(engine)
							var drops: Array = []
							for d in hand.size():
								if d != i and drops.size() < 4:
									drops.append(d)
							if cell2.x >= 0 and drops.size() == 4:
								engine.play_hero_from_hand(i, cell2, drops)
								return true
						continue
					var targets := _bs_targets(engine, card)
					if targets.is_empty() and str(card.target_mode) != "":
						_unplayable_target[card.id] = int(_unplayable_target.get(card.id, 0)) + 1
						continue
					var tgt: Variant = null
					if not targets.is_empty():
						var foes := targets.filter(func(c: Vector2i) -> bool:
							var up: Placement = engine.state.unit_at(c)
							return up != null and up.owner == GameEngine.SIDE_OPPONENT)
						tgt = _pick_foe(engine, foes, 5) if not foes.is_empty() else targets[0]
					engine.use_spell(i, tgt)
					return true
				"效果":
					engine.use_effect(i)
					return true
	return false

var _unplayable_target := {}

func _try_infiltrate(engine: GameEngine, i: int) -> bool:
	## 潜入：选己方盟友 → 任意空格。真实 UI 也是两段点击。
	var ally := Vector2i(-1, -1)
	for c: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[c]
		if p != null and p.owner == GameEngine.SIDE_SELF and p.card.kind == "盟友":
			ally = c
			break
	if ally.x < 0:
		return false
	for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
		for y in FieldState.BOARD_COLS:
			var dst := Vector2i(x, y)
			if dst != ally and not engine.state.board.has(dst):
				var r: String = engine.cast_infiltrate(i, ally, dst)
				# 成功返回描述文本；失败返回「（…）」错误且不扣费
				return not str(r).begins_with("（")
	return false

func _bs_targets(engine: GameEngine, card: CardData) -> Array[Vector2i]:
	## 复用 battle_scene._spell_target_cells 的**同一份**目标逻辑（不重写）。
	if _bs == null:
		_bs = load("res://scripts/battle_scene.gd").new()
	_bs.engine = engine
	return _bs._spell_target_cells(card)

var _bs: Variant = null

func _empty_own_cell(engine: GameEngine) -> Vector2i:
	## 我方半场第一个空格（前 3 行 → 后排）。
	for x in range(FieldState.OPPONENT_ROWS, FieldState.BOARD_ROWS):
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if not engine.state.board.has(c):
				return c
	return Vector2i(-1, -1)

func _units_step(engine: GameEngine) -> bool:
	## 玩家单位行动一轮：能打就打（穿透目标优先），打不着就朝最近的敌人走一步。
	## 做了任一动作返回 true（外层循环会再扫，支持多次行动/移动后接攻击）。
	var mine: Array[Vector2i] = []
	for c: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[c]
		if p != null and p.owner == GameEngine.SIDE_SELF:
			mine.append(c)
	for src in mine:
		var p: Placement = engine.state.unit_at(src)
		if p == null or p.tapped:
			continue
		if p.card.move_speed <= 0 and p.card.power <= 0 and p.card.attack_range <= 0:
			continue
		# 0) 熊（回春）：掉血 ≥6 且本回合够不到敌人时，先奶一口（代替行动）
		if p.card.traits.has("回春") and not p.ability_used \
				and p.health <= p.card.health - 6 \
				and engine.can_activate(src) \
				and engine.legal_attack_targets(src).is_empty():
			engine.activate(src)
			return true
		# 1) 直击敌方 HP（敌方有单位也照样可狙 —— 与胜利条件「敌方 HP 归零」匹配）
		var hpt := engine.hp_targets(src)
		if not hpt.is_empty():
			engine.attack_hp(src, hpt[0])
			return true
		# 2) 攻击敌方单位（能击杀的优先）
		var at := engine.legal_attack_targets(src)
		if not at.is_empty():
			engine.attack(src, _pick_foe(engine, at, p.effective_power()))
			return true
		# 3) 移动逼近：在移速内选「离最近敌人最近」的空格（本回合已移动过则不再走）
		if p.moved:
			continue
		var dst := _best_step(engine, src, p)
		if dst != src:
			engine.move(src, dst)
			return true
	return false

func _foe_units(engine: GameEngine) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in engine.state.board:
		var p: Placement = engine.state.board[c]
		if p != null and p.owner == GameEngine.SIDE_OPPONENT:
			out.append(c)
	return out

func _pick_foe(engine: GameEngine, targets: Array[Vector2i], atk_hint := 0) -> Vector2i:
	## 集火「威胁最高」的敌人：有效攻击力 × 行动次数，平手取离我方 HP 近的；
	## 能被这次攻击直接击杀的目标额外大幅加分（补刀优先，不给「击杀成长」送分）。
	var best := targets[0]
	var best_score := -1.0
	for t in targets:
		var p: Placement = engine.state.unit_at(t)
		if p == null:
			continue
		var atk := p.card.power + p.atk_buff + p.atk_growth - p.atk_debuff
		var score: float = maxi(0, atk) * maxi(1, p.acts_left) * 100.0 \
				- (absi(t.x - FieldState.BOARD_ROWS) + absi(t.y - 1))
		if atk_hint > 0 and p.health <= atk_hint:
			score += 1000.0
		if score > best_score:
			best_score = score
			best = t
	return best

func _best_step(engine: GameEngine, src: Vector2i, p: Placement) -> Vector2i:
	## 移动目标：优先逼近「敌方后排的空格」（能直击 HP 的位置），没有敌人时同理；
	## 距离以曼哈顿估，可达性由 move_path 验证。
	var foes := _foe_units(engine)
	var best := src
	var best_d := 1 << 30
	for x in FieldState.BOARD_ROWS:
		for y in FieldState.BOARD_COLS:
			var c := Vector2i(x, y)
			if c == src or engine.state.board.has(c):
				continue
			var path := engine.move_path(src, c, GameEngine.SIDE_SELF)
			if path.is_empty() or path.size() - 1 > p.card.move_speed:
				continue
			var d := 1 << 29
			# 目标点 = 敌方后排任一空格（那里能打到敌方 HP）
			var back := GameEngine.back_row(GameEngine.SIDE_OPPONENT)
			for col in FieldState.BOARD_COLS:
				var t := Vector2i(back, col)
				if not engine.state.board.has(t):
					d = mini(d, absi(c.x - t.x) + absi(c.y - t.y))
			if d == (1 << 29) and not foes.is_empty():
				for f in foes:
					d = mini(d, absi(c.x - f.x) + absi(c.y - f.y))
			if d < best_d:
				best_d = d
				best = c
	return best

func _drain_ai(engine: GameEngine) -> void:
	var guard := 0
	while not engine.over and guard < 600:
		guard += 1
		var q := engine.ai_action_queue()
		if q.is_empty():
			engine.end_turn()
			return
		engine.run_ai_unit(q[0])
