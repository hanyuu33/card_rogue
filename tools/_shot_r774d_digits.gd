extends SceneTree
## R774d 实机截图：状态词后面的数字改用 DmgNumber 共用笔法（撤掉数字素材）。
## 用法（不能 --headless；中文版不传 --lang，英文版传 --lang=en）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r774d_digits.gd [-- --lang=en]
## 结果写 res://_shots/r774d_zh_numbers.png 或 r774d_en_numbers.png。
##
## 摆法：屏幕坐标陈列墙 3 列 × 5 行（英文词比中文宽，列距 300px 仍不重叠），
## 每条都带数值，重点验收「状态词 + 数字」这一对的字重 / 间距 / 描边是否咬得住。

const UiTheme = preload("res://scripts/ui_theme.gd")

const SAMPLE_COL := Color("ffffff")


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
	print("[r774d] SAVED %s %s" % [name, str(img.get_size())])
	return img


func _stuff(sc: Node) -> void:
	sc._floaters.clear()
	var now: int = sc._now()
	var dur := 2600
	var start := now - int(float(dur) * 0.22)
	# 每条都带数值 —— 数字本来就该和状态词一起看（这才是本轮改动的验收对象）。
	# 坐标写死：左侧「费用 / 效果区」面板占 x 265~395、y 60~300，右侧资源面板从 x 660 起，
	# 手牌从 y 520 起 —— 逐条避开，保证 11 条全部完整可见。
	var samples: Array = [
		[StatusBadge.GLYPH_ICE, "", 110.0, 200.0],
		[StatusBadge.GLYPH_POISON, " -3", 520.0, 200.0],
		[StatusBadge.GLYPH_FLAME, " 2", 110.0, 300.0],
		[StatusBadge.GLYPH_SHIELD, " 5", 320.0, 300.0],
		[StatusBadge.GLYPH_HEAL, " +8", 520.0, 300.0],
		[StatusBadge.GLYPH_BOLT, " -2", 110.0, 400.0],
		[StatusBadge.GLYPH_SWORD, " +3", 320.0, 400.0],
		[StatusBadge.GLYPH_ENERGY, " -3", 520.0, 400.0],
		[StatusBadge.GLYPH_SKULL, "", 110.0, 500.0],
		[StatusBadge.GLYPH_STAR, "", 320.0, 500.0],
		[StatusBadge.GLYPH_TAUNT, "", 520.0, 500.0],
	]
	for row: Array in samples:
		var txt: String = StatusBadge.word_of(int(row[0])) + str(row[1])
		sc._floaters.append({
			"pos": Vector2(float(row[2]), float(row[3])),
			"text": txt,
			"col": SAMPLE_COL,
			"start": start,
			"dur": dur,
			"size": 15,
		})
	print("[r774d] 塞入 %d 条状态飘字，lang=%s" % [sc._floaters.size(), GameI18n.language()])


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
	var lang := GameI18n.language()
	var name := "r774d_zh_numbers" if lang == "zh" else "r774d_en_numbers"
	_snap(name)
	quit()
