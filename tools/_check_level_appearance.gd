extends SceneTree
## 探针：**关卡出现概率**（整局模拟 + 同局去重 + 分层分档）。
##
## 口径逐条对齐 `RunState.next_level()` / `RunState._pick_level()`：
##   * 普通战斗：本局**累计胜场 < 2** → 普通敌人-简单，之后 → 普通敌人-困难（跨层累计）；
##   * 精英：**进房扣完巧克力之后** <= 5 → 精英困难，> 5 → 精英简单；
##   * 第三层直道那一格固定抽 `third_elite_pool()`（= 二层精英困难那 5 关），不吃强弱判定；
##   * 同一关名一局内不重复，**该档池子用光才允许复用**；
##   * Boss 每层固定 1 只（地图名牌与实进同源，不参与去重）。
##
## ⚠️ 池子必须**按层分开**算：`levels_of_tier([tier], layer)` 只抽本层的关，
##    把两层的同档关加起来当一个池子会严重高估供给（第一版探针就踩了这个坑）。
##
## 三个与「池子够不够」直接相关的指标：
##   ① 每局场次（需求侧）；
##   ② 单关每局平均出场次数 = ① ÷ 池子关数（供给压力，越大越缺）；
##   ③ 该档「一局内出现重复关」的概率（池子被用光的直接证据）。
##
## 只读，不改任何游戏数据。

const RUNS := 600
const CHOCO_NORMAL := 12     # 难度 < 8
const CHOCO_TIGHT := 11      # 难度 >= 8（每层少一间）

var _hits := {}       # "layer|tier" -> 总场次
var _level_hits := {} # 关名 -> 总场次
var _level_runs := {} # 关名 -> 出现过（>=1 次）的局数
var _repeat := {}     # tier label -> 「一局内该档有重复关」的局数


func _take(layer: int, tier: int, rng: RandomNumberGenerator, used: Dictionary,
		per_run: Dictionary, pool_override: Array = [],
		per_run_kind: Dictionary = {}) -> void:
	## 复刻 `_pick_level`：先剔已用，全用过才复用。
	var pool: Array = pool_override if not pool_override.is_empty() \
			else GameLevels.levels_of_tier([tier], layer)
	if pool.is_empty():
		return
	var candidates: Array = []
	for lvl in pool:
		if not used.has(str(lvl["name"])):
			candidates.append(lvl)
	if candidates.is_empty():
		candidates = pool
	var pick: Dictionary = candidates[rng.randi() % candidates.size()]
	var nm := str(pick["name"])
	used[nm] = true
	var key := "%d|%d" % [layer, tier]
	_hits[key] = int(_hits.get(key, 0)) + 1
	_level_hits[nm] = int(_level_hits.get(nm, 0)) + 1
	per_run[nm] = int(per_run.get(nm, 0)) + 1
	per_run_kind[nm] = key


func _simulate(seed_val: int, choco_max: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var used := {}
	var battle_wins := 0
	var per_run := {}
	var per_run_kind := {}

	# ---- 第一层 / 第二层：网格游走，踩满巧克力数 ----
	for layer in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO]:
		# ⚠️ `battle_wins` 是**本层**计数（`RunState.advance_layer()` 里清零）——
		#    探针必须逐层归零。第一版漏了这一行，把一层的两场简单档带进了二层，
		#    得出「二层普通简单永不触发（0.2%）」的错误结论。整局累计的是
		#    `total_battle_wins`，它只用于结算，不参与分档。
		battle_wins = 0
		var cells: Array = RogueMap.generate(rng, layer)
		var cur: int = RogueMap.idx(RogueMap.START_COL, RogueMap.START_ROW)
		var seen := {cur: true}
		var choco := choco_max
		var steps := 0
		while choco > 0 and steps < choco_max:
			var fresh: Array = []
			for nb in (cells[cur] as Dictionary).get("doors", []):
				if not seen.has(int(nb)):
					fresh.append(int(nb))
			var nxt := -1
			if not fresh.is_empty():
				nxt = int(fresh[rng.randi_range(0, fresh.size() - 1)])
			else:
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
			if t == "battle":
				var tier: int = GameLevels.TIER_NORMAL_EASY if battle_wins < 2 \
						else GameLevels.TIER_NORMAL_HARD
				_take(layer, tier, rng, used, per_run, [], per_run_kind)
				battle_wins += 1
			elif t == "elite":
				var tier2: int = 3 if choco <= 5 else 2
				_take(layer, tier2, rng, used, per_run, [], per_run_kind)
		# 本层 Boss：固定 1 只，从本层 boss_pool 摇
		var bp: Array = GameLevels.boss_pool(layer)
		if not bp.is_empty():
			var b: Dictionary = bp[rng.randi() % bp.size()]
			var bn := str(b["name"])
			var bkey := "%d|4" % layer
			_hits[bkey] = int(_hits.get(bkey, 0)) + 1
			_level_hits[bn] = int(_level_hits.get(bn, 0)) + 1
			per_run[bn] = int(per_run.get(bn, 0)) + 1
			per_run_kind[bn] = bkey

	# ---- 第三层：直道（起点 → 精英 → 商店 → 篝火 → Boss）----
	_take(GameLayers.LAYER_THREE, 3, rng, used, per_run, GameLevels.third_elite_pool(), per_run_kind)
	var bp3: Array = GameLevels.boss_pool(GameLayers.LAYER_THREE)
	if not bp3.is_empty():
		var bn3 := str((bp3[0] as Dictionary)["name"])
		_hits["3|4"] = int(_hits.get("3|4", 0)) + 1
		_level_hits[bn3] = int(_level_hits.get(bn3, 0)) + 1
		per_run[bn3] = int(per_run.get(bn3, 0)) + 1
		per_run_kind[bn3] = "3|4"

	# ---- 收账：出现过的关、该档是否有重复 ----
	var dup_keys := {}
	for nm in per_run:
		_level_runs[nm] = int(_level_runs.get(nm, 0)) + 1
		if int(per_run[nm]) >= 2 and per_run_kind.has(nm):
			dup_keys[str(per_run_kind[nm])] = true
	for k in dup_keys:
		_repeat[str(k)] = int(_repeat.get(str(k), 0)) + 1


func _pool_size(layer: int, tier: int) -> int:
	if layer == GameLayers.LAYER_THREE:
		return GameLevels.third_elite_pool().size() if tier == 3 \
				else GameLevels.boss_pool(layer).size()
	if tier == 4:
		return GameLevels.boss_pool(layer).size()
	return GameLevels.levels_of_tier([tier], layer).size()


func _pool_list(layer: int, tier: int) -> Array:
	if layer == GameLayers.LAYER_THREE:
		return GameLevels.third_elite_pool() if tier == 3 \
				else GameLevels.boss_pool(layer)
	if tier == 4:
		return GameLevels.boss_pool(layer)
	return GameLevels.levels_of_tier([tier], layer)


func _dump(tag: String) -> void:
	print("\n===== %s（%d 局）=====" % [tag, RUNS])
	print("⚠️ 本表按「层|档」分行：三层精英抽的就是二层精英困难那 5 关，"
			+ "同一个池子的压力被拆成两行看，真实值见下面的「按物理池汇总」。")
	print("%-4s %-14s %5s %9s %10s %10s %8s"
			% ["层", "档位", "池子", "每局场次", "单关每局", "单关出场率", "重复率"])
	var rows: Array = []
	for layer in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO]:
		for tier in [0, 1, 2, 3, 4]:
			rows.append([layer, tier])
	rows.append([GameLayers.LAYER_THREE, 3])
	rows.append([GameLayers.LAYER_THREE, 4])
	for r in rows:
		var layer := int(r[0])
		var tier := int(r[1])
		var key := "%d|%d" % [layer, tier]
		var hits := int(_hits.get(key, 0))
		if hits <= 0:
			continue
		var pool := _pool_size(layer, tier)
		var per_run := float(hits) / float(RUNS)
		var per_level := per_run / float(maxi(1, pool))
		var appear_sum := 0.0
		var appear_n := 0
		for lvl in _pool_list(layer, tier):
			appear_sum += float(int(_level_runs.get(str(lvl["name"]), 0))) / float(RUNS)
			appear_n += 1
		var appear := appear_sum / float(maxi(1, appear_n))
		var rep := float(int(_repeat.get(key, 0))) / float(RUNS)
		print("%-4s %-14s %5d %9.2f %10.2f %9.1f%% %7.1f%%"
				% ["L" + str(layer), GameLevels.tier_name(tier), pool, per_run,
				per_level, appear * 100.0, rep * 100.0])


func _dump_levels() -> void:
	print("\n===== 逐关出场（按物理池分组，每局平均场次 / 一局内出现率）=====")
	## ⚠️ 必须**逐层**取池：`levels_of_tier([tier])` 的 layer 默认是第一层，
	##    旧写法把二三层精英关整段漏掉，读表会以为只有第一层有精英。
	for layer in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO]:
		for tier in [0, 1, 2, 3, 4]:
			var pool: Array[Dictionary] = GameLevels.levels_of_tier([tier], layer)
			if pool.is_empty():
				continue
			var tag2 := ""
			if layer == GameLayers.LAYER_TWO and tier == GameLevels.TIER_ELITE_HARD:
				tag2 = "  ← 三层直道那格也抽这池"
			print("--- L%d %s（%d 关）%s"
					% [layer, GameLevels.tier_name(tier), pool.size(), tag2])
			var rows: Array = []
			for lvl in pool:
				var nm := str(lvl["name"])
				rows.append([float(int(_level_hits.get(nm, 0))) / float(RUNS),
					float(int(_level_runs.get(nm, 0))) / float(RUNS), nm])
			rows.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
			for r in rows:
				print("    %-14s 每局 %.3f 场   一局内出现 %.1f%%"
						% [str(r[2]), float(r[0]), float(r[1]) * 100.0])


func _dump_pools() -> void:
	## 按**物理池**汇总供给压力（R856d 修正）。
	## 三层精英那格抽的是 `third_elite_pool()`，与「二层·精英困难」是**同一批关卡**
	## （`levels_of_tier([TIER_ELITE_HARD], LAYER_TWO)`），所以需求必须合并：
	##   每局场次 = 二层精英困难节点数 + 三层固定那 1 场
	## 只列「本层自己的池」：三层的精英池不重复列（它就是二层那个），只列三层 Boss。
	print("\n===== 按物理池汇总（供给压力真实值，降序）=====")
	print("%-5s %-12s %4s %9s %10s %11s  %s"
			% ["池属", "档位", "关数", "每局场次", "单关每局", "单关出场率", "备注"])
	var data: Array = []
	for layer in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO]:
		for tier in [0, 1, 2, 3, 4]:
			var pool: Array[Dictionary] = GameLevels.levels_of_tier([tier], layer)
			if pool.is_empty():
				continue
			data.append([layer, tier, pool])
	data.append([GameLayers.LAYER_THREE, 4, GameLevels.boss_pool(GameLayers.LAYER_THREE)])
	var out: Array = []
	for d in data:
		var pool: Array = d[2]
		var demand := 0.0
		var appear := 0.0
		for lvl in pool:
			var nm := str(lvl["name"])
			demand += float(int(_level_hits.get(nm, 0))) / float(RUNS)
			appear += float(int(_level_runs.get(nm, 0))) / float(RUNS)
		var n := float(maxi(1, pool.size()))
		out.append([demand / n, demand, appear / n, int(d[0]), int(d[1]), pool.size()])
	out.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	for o in out:
		var layer2 := int(o[3])
		var tier2 := int(o[4])
		var note := ""
		if layer2 == GameLayers.LAYER_TWO and tier2 == GameLevels.TIER_ELITE_HARD:
			note = "含三层固定 1 场"
		elif layer2 == GameLayers.LAYER_THREE:
			note = "三层唯一 Boss"
		print("%-5s %-12s %4d %9.2f %10.2f %10.1f%%  %s"
				% ["L" + str(layer2), GameLevels.tier_name(tier2), int(o[5]),
				float(o[1]), float(o[0]), float(o[2]) * 100.0, note])


func _reset() -> void:
	_hits.clear()
	_level_hits.clear()
	_level_runs.clear()
	_repeat.clear()


func _initialize() -> void:
	GameSettings.ensure_loaded()
	for i in RUNS:
		_simulate(424242 + i * 7919, CHOCO_NORMAL)
	_dump("难度 < 8（每层 12 间）")
	_dump_pools()
	_dump_levels()
	_reset()
	for i in RUNS:
		_simulate(424242 + i * 7919, CHOCO_TIGHT)
	_dump("难度 >= 8（每层 11 间）")
	_dump_pools()
	quit(0)
