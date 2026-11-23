extends SceneTree
## R841 出图：锤子 7018（直击眩晕）/ 润滑油 7019（选手卡 -3 费）的实机帧。
##   ① r841_hammer.png —— 一个敌人被锤子砸中后的战场（眩晕状态 + 工具栏两件新工具）
##   ② r841_pick.png   —— 润滑油点「使用」后弹出的选卡页（候选 = 手牌）
##   ③ r841_bar.png    —— 工具栏三格：锤子 / 润滑油 / 空位（44px 下能不能认出来）
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r841.gd

func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	await _wait(3)
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r841_%s.png" % name)
	print("[r841] SAVED %s %s" % [name, str(img.get_size())])


func _clean(sc: Variant) -> void:
	## 收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程数据（R810 / R832 / R839 同款）。
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
	# 教程浮层是 CanvasLayer 且每帧自绘，藏 / free 都会留半张底板 →
	# 出图前把教程 id 全标记成已看（R839 实测三次得出的正解）。
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
	var lvl: Dictionary = (GameLevels.builtin_levels()[0] as Dictionary).duplicate(true)
	lvl["tutorial"] = []
	RunState.pending_level = lvl
	# 工具栏：锤子 / 润滑油 / 空位
	RunState.traps = [7018, 7019, -1]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	_clean(sc)

	# 摆一个敌方单位到 (0, 1)，用锤子砸它（走引擎唯一口，界面只负责画）
	# ⚠️ 直接 `state.place()` 摆出来的单位**没有画面**（场景只在自身流程里建节点），
	# 所以砸场上现成的敌人：关卡开场已经有两只鸭子骑士。
	var targets: Array[Vector2i] = sc.engine.trap_target_cells()
	if not targets.is_empty():
		var cell0: Vector2i = targets[0]
		var foe: Placement = sc.engine.state.unit_at(cell0)
		var hp0: int = foe.health if foe != null else -1
		var hit: bool = sc.engine.use_tool_on_unit(7018, cell0)
		print("[r841] hammer hit=%s cell=%s stun_left=%d hp=%d→%d" % [
				str(hit), str(cell0), foe.stun_left if foe != null else -1,
				hp0, foe.health if foe != null else -1])
	sc.queue_redraw()
	await _wait(8)
	sc.queue_redraw()
	await _wait(2)
	await _snap("hammer")

	# ② 润滑油：进入选卡（候选 = 此刻手牌），面板由 `_sync_pick` 下一帧弹出
	var opened: bool = sc.engine.begin_tool_pick(7019)
	print("[r841] oil pick opened=%s hand=%d kind=%s" % [
			str(opened), sc.engine.state.hand.size(), sc.engine.tool_pick_kind])
	await _wait(14)
	sc.queue_redraw()
	await _wait(2)
	await _snap("pick")
	sc.engine.tool_pick_cancel()
	await _wait(10)

	# ③ 工具栏三格
	sc._clear_selection()
	sc.queue_redraw()
	await _wait(4)
	await _snap("bar")
	quit()
