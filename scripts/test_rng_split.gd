extends SceneTree
## R871 回归：**战斗随机链** 与 **非战斗随机链** 各自被种子确定，且彼此不干涉。
##
## 口径（店长）：「需要专门有一个战斗随机数，依然来自种子，但是和非战斗随机数不通用。
## 战斗随机数需要决定包括工具使用，卡牌随机的随机数。确保这两个都能被种子确定
## 但是不互相干涉。」
##
## 这份测试只钉**关系**，不钉具体数值 —— 数值会随卡池 / 关卡调整变化，而下面四条
## 关系是「两条链分家」这件事的定义：
##   ① 非战斗链多抽 N 次 → 战斗种子序列**一个不变**（非战斗 → 战斗 无干涉）；
##   ② 战斗内抽 M 次 → 非战斗链之后的序列**一个不变**（战斗 → 非战斗 无干涉）；
##   ③ 同 (种子, 场次) → 战斗种子 / 卡牌随机 / 工具填栏结果**完全可复现**；
##   ④ 存档带上战斗序号 → 续档重打这一场拿回同一个种子。
##
## ⚠️ 这四条里任何一条红，都说明有人把战斗种子又接回 `run_rng`（或反过来）。
##    那是本轮要根除的病，不是「数值变了改期望值」能糊过去的。

var _passed := 0
var _failed := 0
var _fails: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_fails.append(msg)


func _start(seed_i: int) -> void:
	## 统一入口：走真实开局（地图 / 关卡 / 初始卡组都照常生成），只把种子钉死。
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.DRUID, seed_i)


func _battle_seeds(seed_i: int, burn: int, n: int) -> Array:
	## 先让**非战斗链**抽 burn 次，再连续开 n 场战斗，收集每场的卡牌种子。
	_start(seed_i)
	for i in burn:
		RunState.run_rng.randi()
	var out: Array = []
	for i in n:
		out.append(RunState.next_battle_seed())
	return out


func _run_fingerprint(seed_i: int, battles: int) -> Array:
	## 打 battles 场（每场战斗内抽 200 次），然后取非战斗链接下来的 8 颗做指纹。
	_start(seed_i)
	for b in battles:
		RunState.next_battle_seed()
		for k in 200:
			RunState.battle_rng.randi()
	var out: Array = []
	for i in 8:
		out.append(RunState.run_rng.randi())
	return out


func _card_seq(seed_i: int, burn: int, n := 8) -> Array:
	## 取某一场的卡牌子流（引擎 `rng` 用的就是它）的前 n 颗。
	_start(seed_i)
	for i in burn:
		RunState.run_rng.randi()
	RunState.next_battle_seed()
	var r := RandomNumberGenerator.new()
	r.seed = RunState.battle_seed
	var out: Array = []
	for i in n:
		out.append(r.randi())
	return out


func _empty_toolbar() -> void:
	RunState.traps.clear()
	for i in 3:
		RunState.traps.append(-1)


func _tool_fill(seed_i: int, pick: int) -> Array:
	## 连开 pick+1 场，每场用战斗链填一次工具栏，返回每一场填出来的三格内容。
	_start(seed_i)
	var out: Array = []
	for b in pick + 1:
		RunState.next_battle_seed()
		_empty_toolbar()
		RunState.fill_toolbar_with_shop_tools(RunState.battle_rng)
		out.append(RunState.traps.duplicate())
	return out


func _init() -> void:
	var seed_a := 424242
	var seed_b := 909090

	# ① 非战斗链的消耗不影响战斗种子
	var s_plain := _battle_seeds(seed_a, 0, 6)
	var s_burned := _battle_seeds(seed_a, 50, 6)
	check(s_plain.size() == 6 and s_plain == s_burned,
			"① 非战斗链多抽 50 次后，接下来 6 场的战斗种子应一字不差（%s vs %s）"
			% [str(s_plain), str(s_burned)])
	# 同一条种子重跑 → 战斗种子序列也必须一样（否则「种子决定这一局」就不成立）
	check(s_plain == _battle_seeds(seed_a, 0, 6),
			"① 同一条种子重跑两次，战斗种子序列应完全相同")
	check(s_plain != _battle_seeds(seed_b, 0, 6),
			"① 换一条种子，战斗种子序列必须不同")

	# ② 战斗内的消耗不推进非战斗链
	check(_run_fingerprint(seed_a, 0) == _run_fingerprint(seed_a, 5),
			"② 打了 5 场（每场战斗内抽 200 次）之后，非战斗链的后续序列应完全不变")
	check(_run_fingerprint(seed_a, 0) == _run_fingerprint(seed_a, 0),
			"② 同一条种子的非战斗链本身应可复现")
	# 反证两条：证明上面那条不是「指纹永远相等」的空转。
	#   * 非战斗链多抽 5 次 → 指纹必须变（指纹确实对消耗敏感）；
	#   * 模拟旧写法「每开一场就从 run_rng 摘一颗」→ 指纹必须变（这正是 R871 根除的耦合）。
	_start(seed_a)
	for i in 5:
		RunState.run_rng.randi()
	var fp_extra: Array = []
	for i in 8:
		fp_extra.append(RunState.run_rng.randi())
	check(fp_extra != _run_fingerprint(seed_a, 0),
			"② 指纹自检：非战斗链多抽 5 次必须改变后续序列（否则这条测试是空转）")
	_start(seed_a)
	for b in 5:
		RunState.run_rng.randi()
	var fp_old: Array = []
	for i in 8:
		fp_old.append(RunState.run_rng.randi())
	check(fp_old != _run_fingerprint(seed_a, 0),
			"② 反证：旧的「每场从 run_rng 摘一颗」写法必须会让指纹变化")

	# ③ 卡牌子流由战斗种子确定，且与非战斗链状态无关
	check(_card_seq(seed_a, 0) == _card_seq(seed_a, 50),
			"③ 卡牌随机不该受非战斗链抽了多少次影响")
	check(_card_seq(seed_a, 0) == _card_seq(seed_a, 0),
			"③ 同一条种子同一场次，卡牌随机序列应完全一致")
	check(_card_seq(seed_a, 0) != _card_seq(seed_b, 0),
			"③ 换一条种子，卡牌随机序列必须不同")

	# ④ 工具使用：吃战斗链、不碰非战斗链、同种子可复现
	_start(seed_a)
	var st_before := RunState.run_rng.state
	RunState.next_battle_seed()
	_empty_toolbar()
	RunState.fill_toolbar_with_shop_tools(RunState.battle_rng)
	check(RunState.run_rng.state == st_before,
			"④ 战斗中「快送鸭填满工具栏」不该推进非战斗链（state 必须原地不动）")
	check(_tool_fill(seed_a, 2) == _tool_fill(seed_a, 2),
			"④ 同一条种子，前三场填出来的工具组合应完全一致")
	check(_tool_fill(seed_a, 2) != _tool_fill(seed_b, 2),
			"④ 换一条种子，工具填充结果必须不同")

	# ⑤ 派生：场次不同 → 种子不同；卡牌与工具两条子流不重合
	var seen := {}
	for n in range(1, 21):
		seen[RunState.seed_of("battle", n)] = true
	check(seen.size() == 20, "⑤ 1..20 场应得到 20 个互不相同的战斗种子（实际 %d 个）" % seen.size())
	check(RunState.seed_of("battle", 1) != RunState.seed_of("battle_tools", 1),
			"⑤ 卡牌子流与工具子流必须用不同派生，否则「工具第一抽」就是「卡牌第一抽」")

	# ⑥ 真实洗牌：同一个战斗种子，两次洗出来的卡组顺序必须一致
	var repo := CardRepo.load_json()
	var deck: Array[CardData] = repo.starter_deck()
	var brng1 := RandomNumberGenerator.new()
	brng1.seed = RunState.seed_of("battle", 7)
	var st1 := FieldState.new(deck, 30, 30, -1, "R871", true, brng1)
	var order1: Array = []
	for c: CardData in st1.deck:
		order1.append(c.id)
	var brng2 := RandomNumberGenerator.new()
	brng2.seed = RunState.seed_of("battle", 7)
	var st2 := FieldState.new(deck, 30, 30, -1, "R871", true, brng2)
	var order2: Array = []
	for c: CardData in st2.deck:
		order2.append(c.id)
	check(order1 == order2, "⑥ 同一战斗种子两次洗牌，牌序必须一致")
	check(order1.size() == deck.size(), "⑥ 洗牌不该丢牌 / 多牌")

	# ⑦ 存档：战斗序号要进快照，否则续档重打这一场会换种子
	var snap := RunSave.snapshot()
	check(snap.has("battle_seq"), "⑦ 存档快照必须带 battle_seq")
	check(int(snap.get("battle_seq", -1)) == RunState.battle_seq,
			"⑦ 快照里的 battle_seq 应与内存一致")

	# ⑧ 源码闸门：不许有人把战斗种子接回非战斗链
	var bs := ""
	if FileAccess.file_exists("res://scripts/battle_scene.gd"):
		bs = FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	if bs != "":
		check(bs.find("RunState.next_battle_seed()") >= 0,
				"⑧ battle_scene 必须用 RunState.next_battle_seed() 取战斗种子")
		check(bs.find("RunState.run_rng.randi()") < 0,
				"⑧ battle_scene 里不许再出现 RunState.run_rng.randi()（那是旧的耦合写法）")
	var ge := ""
	if FileAccess.file_exists("res://scripts/game_engine.gd"):
		ge = FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	if ge != "":
		check(ge.find("fill_toolbar_with_shop_tools(RunState.battle_rng)") >= 0,
				"⑧ 战斗内使用工具必须把 battle_rng 传给 fill_toolbar_with_shop_tools")

	# ⚠️ 汇总行格式要与 `_verify.py` 的正则对齐（`(\d+) 通过 / (\d+) 失败`）——
	#    写成「22 条通过，0 条失败」会被数成 0✓ / 0✗，看着像没跑（R870 的 smoke 踩过）。
	print("== R871 战斗/非战斗随机链：%d 通过 / %d 失败 ==" % [_passed, _failed])
	for m: String in _fails:
		print("  ✗ ", m)
	quit(0 if _failed == 0 else 1)
