extends SceneTree
## R745 一次性探针：野性图腾（工具 7008）在**战斗界面**里
## 「点一下 → 全体盟友 +2 力量 → 栏位空出来 → 信息栏能看到来源」全链。
##
## 用法（headless 即可，不渲染）：
##   Godot_v4.3-stable_win64_console.exe --headless --path . \
##     --script res://tools/_t_r745_totem_probe.gd
##
## 为什么不能只靠 test_engine：那边验的是 `GameEngine.use_tool()` 的数值与字段，
## 而「摘槽」在界面层（`battle_scene._use_tool_slot()` → `RunState.consume_trap()`）、
## 「力量来源条」在 `Placement.info_lines()` —— 三条路只验一条，就可能出现
## 「力量加了、栏位还占着」或「加了但玩家看不出是谁加的」。
##
## 全程切测试档（ProfileData / RunSave.set_test_mode），绝不碰玩家存档。

var _fails := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("✓ ", msg)
	else:
		_fails += 1
		print("✗ ", msg)


func _has_label(lines: Array, word: String) -> bool:
	for l: Dictionary in lines:
		if str(l.get("label", "")).contains(word):
			return true
	return false


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026111502
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	RunState.traps = [7008, -1, -1]

	var sc: Node = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	for i in 40:
		await process_frame
	if sc.engine == null:
		print("✗ 战斗没建起来（engine == null）")
		quit(1)
		return

	var td: TrapData = TrapRepo.load_json().get_trap(7008)
	_ok(td != null and td.is_usable(), "野性图腾是使用型工具（is_usable）")
	_ok(td != null and td.ally_atk == 2, "野性图腾的数据里写明 ally_atk = 2")
	_ok(RunState.trap_at(0) == 7008, "开打前进工具栏：第 1 格是野性图腾")

	# 场上先站一个盟友（用一张真实盟友卡，走 place 的唯一口）
	var repo := CardRepo.load_json()
	var ally: CardData = CardData.from_dict(repo.get_card(8003).to_dict())
	var p: Placement = sc.engine.state.place(ally, Vector2i(1, 4), GameEngine.SIDE_SELF)
	sc.engine._relic_on_enter_buffs(p)
	var base: int = p.effective_power()
	_ok(base == ally.power, "用之前没有额外力量（%d）" % base)
	_ok(not _has_label(p.status_entries(), "野性图腾"), "用之前信息栏没有野性图腾的来源条")

	sc._use_tool_slot(0, td)
	_ok(p.effective_power() == base + GameEngine.WILD_TOTEM_ATK,
			"点一下：盟友 +%d 力量（%d → %d）"
			% [GameEngine.WILD_TOTEM_ATK, base, p.effective_power()])
	_ok(RunState.trap_at(0) == -1, "用掉即摘槽：第 1 格变成空槽")
	_ok(sc.engine._wild_totem_atk == GameEngine.WILD_TOTEM_ATK,
			"本场标记记下了这次使用（之后上场的人也要吃）")
	var lines: Array = p.status_entries()
	_ok(_has_label(lines, "野性图腾"),
			"信息栏出现来源条（玩家要看得出这 +2 是谁加的）")

	# 空槽再点一次不能有任何变化（也不能再叠一次）
	var pw2: int = p.effective_power()
	sc._use_tool_slot(0, td)
	_ok(p.effective_power() == pw2 and sc.engine._wild_totem_atk == GameEngine.WILD_TOTEM_ATK,
			"空槽再点一次无效（力量仍是 +%d）" % GameEngine.WILD_TOTEM_ATK)

	# 用掉之后再上场的盟友同样吃（界面层的落地口 = _relic_on_enter_buffs）
	var p2: Placement = sc.engine.state.place(
			CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(2, 4), GameEngine.SIDE_SELF)
	sc.engine._relic_on_enter_buffs(p2)
	_ok(p2.effective_power() == base + GameEngine.WILD_TOTEM_ATK,
			"用掉之后才上场的盟友同样 +%d（%d）"
			% [GameEngine.WILD_TOTEM_ATK, p2.effective_power()])

	print("== R745 探针：%s ==" % ("全过" if _fails == 0 else "%d 项失败" % _fails))
	RunState.traps = [-1, -1, -1]
	quit(0 if _fails == 0 else 1)
