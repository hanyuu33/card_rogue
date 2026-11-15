extends SceneTree
## R743 一次性探针：烤肉（7007）在**战斗界面**里「主动点一下 → 回血 → 栏位空出来」全链。
##
## 用法（headless 即可，不渲染）：
##   Godot_v4.3-stable_win64_console.exe --headless --path . \
##     --script res://tools/_t_r742_bbq_probe.gd
##
## 为什么不能只靠 test_engine：那边验的是 `GameEngine.use_tool()` 的**数值**，
## 而「摘槽」这一步在界面层（`battle_scene._use_tool_slot()` → `RunState.consume_trap()`）。
## 两条路只验一条，就可能出现「血回了、栏位还占着」（或反过来）。
##
## 全程切测试档（ProfileData / RunSave.set_test_mode），绝不碰玩家存档。

var _fails := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("✓ ", msg)
	else:
		_fails += 1
		print("✗ ", msg)


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
	rng.seed = 2026111501
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	RunState.hp = 20
	RunState.max_hp = 40
	RunState.traps = [7007, -1, -1]

	var sc: Node = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	for i in 40:
		await process_frame
	if sc.engine == null:
		print("✗ 战斗没建起来（engine == null）")
		quit(1)
		return
	sc.engine.state.max_hp_self = 40
	sc.engine.state.hp_self = 20

	var td: TrapData = TrapRepo.load_json().get_trap(7007)
	_ok(td != null and td.is_usable(), "烤肉是使用型工具（is_usable）")
	_ok(RunState.trap_at(0) == 7007, "开打前进工具栏：第 1 格是烤肉")

	var hp_before: int = sc.engine.state.hp_self
	sc._use_tool_slot(0, td)
	var hp_after: int = sc.engine.state.hp_self
	_ok(hp_after == hp_before + 10,
			"点一下就吃：回复 25%% 最大生命（%d → %d，应 +10）" % [hp_before, hp_after])
	_ok(RunState.trap_at(0) == -1, "用掉即摘槽：第 1 格变成空槽")
	_ok(not RunState.has_barbecue_tool(), "工具栏里已经没有烤肉")

	# 再点一次（空槽）不能有任何变化
	var hp2: int = sc.engine.state.hp_self
	sc._use_tool_slot(0, td)
	_ok(sc.engine.state.hp_self == hp2, "空槽再点一次无效（不会凭空回血）")

	# 满血时也允许吃（口径：玩家的选择，不替他拦），但摘槽照样生效
	RunState.traps = [7007, -1, -1]
	sc.engine.state.hp_self = sc.engine.state.max_hp_self
	sc._use_tool_slot(0, td)
	_ok(RunState.trap_at(0) == -1 and sc.engine.state.hp_self == sc.engine.state.max_hp_self,
			"满血使用：血不变、栏位照样空出来")

	print("== R743 探针：%s ==" % ("全过" if _fails == 0 else "%d 项失败" % _fails))
	RunState.traps = [-1, -1, -1]
	quit(0 if _fails == 0 else 1)
