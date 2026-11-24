extends SceneTree
## 探针：战斗关卡的「分层 × 分档」编排与数值分布。
## 口径：
##   * tier 五档见 GameLevels.TIER_*；layer 见 GameLevels.layer_of；
##   * 敌方 HP 走 `GameLevels.enemy_hp_of()`（已含精英 +10 / Boss +20 与整体 ×2）；
##   * 单位攻击 / 生命直接读编成元组第 3、4 项（卡库命中时以卡库为准，这里只作分布参考）。
## 另附「随机游走」遭遇抽样：模拟一层 12 步内踩到的节点，按 next_level 的规则折算档位。

const WALKS := 400

func _unit_stats(lvl: Dictionary) -> Array:
	var atk := 0
	var hp := 0
	var n := 0
	for e in lvl.get("enemy_units", []):
		if not (e is Array) or (e as Array).size() < 4:
			continue
		atk += int(e[2])
		hp += int(e[3])
		n += 1
	return [n, atk, hp]


func _dump_tiers() -> void:
	print("===== 分层 × 分档 编排（builtin_levels，共 %d 关）=====" % GameLevels.builtin_levels().size())
	for layer in [1, 2, 3]:
		for tier in [0, 1, 2, 3, 4]:
			var pool: Array[Dictionary] = GameLevels.levels_of_tier([tier], layer)
			if pool.is_empty():
				continue
			var hps: Array = []
			for lvl in pool:
				hps.append(GameLevels.enemy_hp_of(lvl))
			var hmin: int = hps.min()
			var hmax: int = hps.max()
			var names: Array = []
			for lvl in pool:
				names.append(str(lvl.get("name", "")))
			print("  L%d %-14s ×%d  敌HP %d~%d  | %s"
					% [layer, GameLevels.tier_name(tier), pool.size(), hmin, hmax,
					"、".join(names)])
	print("--- 各层各档「场上单位」强度区间（n=单位数 / atk=攻击合计 / uhp=生命合计）---")
	for layer in [1, 2, 3]:
		for tier in [0, 1, 2, 3, 4]:
			var pool2: Array[Dictionary] = GameLevels.levels_of_tier([tier], layer)
			if pool2.is_empty():
				continue
			var atks: Array = []
			var uhps: Array = []
			var ns: Array = []
			for lvl in pool2:
				var st2 := _unit_stats(lvl)
				atks.append(int(st2[1]))
				uhps.append(int(st2[2]))
				ns.append(int(st2[0]))
			var a_sum := 0
			var h_sum := 0
			for v in atks:
				a_sum += int(v)
			for v in uhps:
				h_sum += int(v)
			print("  L%d %-14s atk %2d~%-3d (均 %.1f)   uhp %3d~%-4d (均 %.1f)   单位数 %d~%d"
					% [layer, GameLevels.tier_name(tier), int(atks.min()), int(atks.max()),
					float(a_sum) / float(atks.size()), int(uhps.min()), int(uhps.max()),
					float(h_sum) / float(uhps.size()), int(ns.min()), int(ns.max())])
	print("--- 逐关细目（层 / 档 / 名 / 敌HP / 单位数 / 单位攻击合计 / 单位生命合计）---")
	for lvl in GameLevels.builtin_levels():
		var st := _unit_stats(lvl)
		print("  L%d T%d %-12s hp=%-4d n=%d atk=%-3d uhp=%-4d"
				% [GameLevels.layer_of(lvl), int(lvl.get("tier", -1)),
				str(lvl.get("name", "")), GameLevels.enemy_hp_of(lvl),
				int(st[0]), int(st[1]), int(st[2])])


func _walk_layer(layer: int, s: int) -> Dictionary:
	## 从起点出发踩满 12 个新房间（回头路不扣块，与 RunState.advance 同口径）；
	## 按 next_level 的判据折算档位。
	var rng := RandomNumberGenerator.new()
	rng.seed = 900000 + s * 7919 + layer * 17
	var cells: Array = RogueMap.generate(rng, layer)
	var start_i := RogueMap.idx(RogueMap.START_COL, RogueMap.START_ROW)
	var cur := start_i
	var seen := {start_i: true}
	var choco: int = 12
	# 第二层开局时本局早已打完前两场 → battle_wins 起始按 6 计（只影响普通档的取档）
	var battle_wins: int = 0 if layer == GameLayers.LAYER_DEFAULT else 6
	var hits := {}
	var steps := 0
	while choco > 0 and steps < 12:
		# ① 优先走没去过的邻居
		var fresh: Array = []
		for nb in (cells[cur] as Dictionary).get("doors", []):
			if not seen.has(int(nb)):
				fresh.append(int(nb))
		var nxt := -1
		if not fresh.is_empty():
			nxt = int(fresh[rng.randi_range(0, fresh.size() - 1)])
		else:
			# ② 否则 BFS 找最近的未访问格，沿已走过的路过去（回头不计块）
			var prev := {cur: -1}
			var queue: Array = [cur]
			var target := -1
			while not queue.is_empty() and target < 0:
				var u := int(queue.pop_front())
				for nb2 in (cells[u] as Dictionary).get("doors", []):
					var v := int(nb2)
					if prev.has(v):
						continue
					prev[v] = u
					if not seen.has(v):
						target = v
						break
					queue.append(v)
			if target < 0:
				break
			nxt = target
		seen[nxt] = true
		cur = nxt
		steps += 1
		choco = maxi(0, choco - 1)
		var t := str((cells[cur] as Dictionary).get("type", ""))
		var tag := ""
		if t == "battle":
			tag = "普通简单" if battle_wins < 2 else "普通困难"
			battle_wins += 1
		elif t == "elite":
			tag = "精英困难" if choco <= 5 else "精英简单"
		elif t == "boss":
			tag = "Boss"
		if tag != "":
			hits[tag] = int(hits.get(tag, 0)) + 1
	return {"steps": steps, "hits": hits}


func _dump_walk() -> void:
	print("===== 随机游走遭遇抽样（每层 %d 次，单次最多 12 步）=====" % WALKS)
	for layer in [1, 2]:
		var tot := {}
		var steps_sum := 0
		for s in WALKS:
			# 第二层开局时本局早已打完前两场 → battle_wins 起始按 6 计（只影响普通档）
			var r := _walk_layer(layer, s)
			steps_sum += int(r["steps"])
			for k in (r["hits"] as Dictionary):
				tot[k] = int(tot.get(k, 0)) + int(r["hits"][k])
		var sum := 0
		for k in tot:
			sum += int(tot[k])
		print("  --- 第%d层（平均走 %.2f 步，遭遇 %d 场）---"
				% [layer, float(steps_sum) / float(WALKS), sum])
		for k in ["普通简单", "普通困难", "精英简单", "精英困难", "Boss"]:
			if not tot.has(k):
				continue
			print("    %-6s %5d  %6.1f%%" % [k, int(tot[k]), 100.0 * float(tot[k]) / float(maxi(1, sum))])


func _initialize() -> void:
	GameSettings.ensure_loaded()
	_dump_tiers()
	_dump_walk()
	quit(0)
