extends SceneTree
## R839 出图：大蒜 7017（指定空格 3 个我方回合不可使用）的实机帧。
##   ① r839_seal_board.png —— 两格被封（剩 2 / 剩 3）：暗底 + 对角封条 + 蒜图标 + 角标回合数
##   ② r839_seal_drag.png  —— 从工具栏拖大蒜时的高亮：封锁格**不**亮（绿格是可放的空格）
##   ③ r839_seal_bar.png   —— 工具栏三格：大蒜 / 炼金炸弹 / 空位（图标兜底能不能认出来）
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r839.gd

func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _kill_tutorial(n: Node) -> void:
	## 教程浮层（TutorialOverlay，CanvasLayer layer=60）由导演在进场时挂上 ——
	## 只把 `_tutorial` 清空不够、只设 visible 也压不住（它每帧自己画）。
	## 出图前直接 queue_free 掉整棵子树（R836 那种「只隐藏」在这里不成立）。
	for ch in n.get_children():
		if String(ch.name).to_lower().contains("tutorial"):
			ch.queue_free()
			continue
		_kill_tutorial(ch)


func _snap(name: String) -> void:
	await _wait(3)
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r839_%s.png" % name)
	print("[r839] SAVED %s %s" % [name, str(img.get_size())])


func _clean(sc: Variant) -> void:
	## 收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程数据（R810 / R832 同款）。
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc.status_text = ""


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	# 教程判据是 `ProfileData.is_tutorial_seen(id)` —— 测试档是新档，会把「卷卷」那一串
	# 全弹一遍（盖住整个战场）。出图前先把它们全标记成已看，比事后藏浮层稳得多
	# （藏 / free 都会留下半张底板，实测三次）。
	for tid in [TutorialScript.ID_MAP_WALK, TutorialScript.ID_MAP_CHOCO,
			TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tid)
	ProfileData.flush()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	RunState.pending_node = {"type": "battle"}
	# ⚠️ 第一关自带教程（「卷卷」那五页）—— 出图前先把 tutorial 清掉，
	# 否则浮层盖住整个战场。等它弹出来再隐藏 / 释放都晚了（实测会留半张底板）。
	var lvl: Dictionary = (GameLevels.builtin_levels()[0] as Dictionary).duplicate(true)
	lvl["tutorial"] = []
	RunState.pending_level = lvl
	RunState.traps = [7017, 7001, -1]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	_clean(sc)

	# 两格封锁：一格剩 2 个我方回合、一格剩 3（刚放）
	sc.engine.state.seal_cell(Vector2i(1, 1), 2)
	sc.engine.state.seal_cell(Vector2i(4, 0), 3)
	sc.queue_redraw()
	await _wait(8)
	sc.queue_redraw()
	await _wait(2)
	await _snap("seal_board")
	print("[r839] board sealed=%s trap_fields=%s" % [
			str(sc.engine.state.sealed_cells.keys()), str(sc.engine.state.trap_fields.keys())])

	# ② 拖拽大蒜：可放格高亮（封锁格必须不在候选里）
	sc._trap_drag_slot = 0
	sc._trap_drag_cells = sc.engine.trap_drop_cells(7017)
	sc._trap_drag_pos = sc._cell_center(Vector2i(3, 1))
	sc.queue_redraw()
	await _wait(8)
	sc.queue_redraw()
	await _wait(2)
	await _snap("seal_drag")
	print("[r839] drop_cells=%d sealed_in_cells=%s" % [
			sc._trap_drag_cells.size(),
			str(sc._trap_drag_cells.has(Vector2i(1, 1)) or sc._trap_drag_cells.has(Vector2i(4, 0)))])
	sc._cancel_trap_drag()
	sc.queue_redraw()
	await _wait(4)
	await _snap("seal_bar")
	quit()
