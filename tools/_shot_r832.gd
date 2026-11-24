extends SceneTree
## R832 出图：缺陷时钟（6084）**角标**的实机帧 —— 验「现在有计数了」。
##   ① r832_badge_wait.png —— 本场还差 8 张 → 角标「8」
##   ② r832_badge_done.png —— 本场已触发过 → 角标「0」
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r832.gd
##
## 与 R810 出图同一套口径：先 `start_run()` 再实例化 battle.tscn，走玩家进战斗的同一条路。
## 档案切测试档 —— 外部驱动跑完逐文件还原（见 tools/_shot_r832.sh）。

func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r832_%s.png" % name)
	print("[r832] SAVED %s %s" % [name, str(img.get_size())])


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	# 收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程高亮（R810 同款）
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc.status_text = ""
	# 只放缺陷时钟一件，角标最显眼
	var ids: Array[int] = [6084]
	RunState.relics = ids
	RunState.spent_relics = []
	sc.engine.self_relics = ids
	# ① 本场打出了 4 张 → 还差 8 张
	sc.engine._clock_plays = 4
	sc.queue_redraw()
	await _wait(6)
	sc.queue_redraw()
	await _wait(2)
	_snap("badge_wait")
	print("[r832] WAIT left=%d badge=\"%s\"" % [
			sc.engine.defect_clock_left(),
			RunState.relic_badge_text(6084, sc.engine.defect_clock_left())])
	# ② 本场已触发过（第 12 张跳过了敌方回合）→ 角标「0」
	sc.engine._clock_plays = 12
	sc.queue_redraw()
	await _wait(6)
	sc.queue_redraw()
	await _wait(2)
	_snap("badge_done")
	print("[r832] DONE left=%d badge=\"%s\"" % [
			sc.engine.defect_clock_left(),
			RunState.relic_badge_text(6084, sc.engine.defect_clock_left())])
	quit()
