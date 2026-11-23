extends SceneTree
## R774c 实机截图：英文状态特效文字（非中文语言统一英文艺术字，店长口径）。
## 用法（不能 --headless，加 `-- --lang=en` 走 GameSettings 的官方出图口）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r774c_en_art.gd -- --lang=en
## 结果写 res://_shots/r774c_en_*.png。
##
## 11 个英文词比中文宽，战斗棋盘（横屏转置后 3 列）放不下 —— 改用**屏幕坐标陈列墙**，
## 叠在真实战斗背景上，每个词 + 数字完整展示、互不重叠，供店长验收拼写 / 质感 / 数字拼接。


func _initialize() -> void:
	_m.call_deferred()


func _setup_run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	for tid: String in [TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tid)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> Image:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/%s.png" % name)
	print("[r774c] SAVED %s %s" % [name, str(img.get_size())])
	return img


func _stuff(sc: Node) -> void:
	## 样本 text 全部走 StatusBadge.word_of() —— 同一段代码在 zh 下给中文、en 下给英文，
	## 截图顺带验证「word_of 切换 + 英文素材渲染」两件事。
	## 布局 = 4 列 × 3 行屏幕坐标陈列墙（x 间距 330px > 最长词宽，y 间距 130px）。
	sc._floaters.clear()
	var now: int = sc._now()
	var dur := 2600
	var start := now - int(float(dur) * 0.22)
	var samples: Array = [
		{"x": 168.0, "y": 180.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_ICE)},
		{"x": 470.0, "y": 180.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_FLAME) + " 2"},
		{"x": 772.0, "y": 180.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_SHIELD) + " 5"},
		{"x": 168.0, "y": 300.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_POISON) + " -3"},
		{"x": 470.0, "y": 300.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_HEAL) + " +8"},
		{"x": 772.0, "y": 300.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_BOLT) + " -2"},
		{"x": 168.0, "y": 420.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_STAR)},
		{"x": 470.0, "y": 420.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_TAUNT)},
		{"x": 772.0, "y": 420.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_SWORD) + " +3"},
		{"x": 168.0, "y": 540.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_SKULL)},
		{"x": 470.0, "y": 540.0, "text": StatusBadge.word_of(StatusBadge.GLYPH_ENERGY) + " -3"},
	]
	for s: Dictionary in samples:
		sc._floaters.append({
			"pos": Vector2(float(s["x"]), float(s["y"])),
			"text": str(s["text"]),
			"col": Color("ffffff"),
			"start": start,
			"dur": dur,
			"size": 15,
		})
	print("[r774c] 塞入 %d 条英文状态飘字，lang=%s" % [sc._floaters.size(), GameI18n.language()])


func _m() -> void:
	_setup_run()
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc.status_text = ""
	for i in 30:
		sc._tutorial = []
		sc._tutorial_finished = true
		var tut: Node = sc.get_node_or_null(TutorialDirector.OVERLAY_NAME)
		if tut != null:
			tut.queue_free()
		paused = false
		await process_frame
	paused = false
	await _wait(10)

	_stuff(sc)
	sc.queue_redraw()
	await _wait(3)
	_snap("r774c_en_art")
	quit()
