extends SceneTree
## R770 实机截图：伤害数字（飘字 + 拖卡预览）。
##
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r770_dmg.gd
## 结果写 res://_shots/r770_*.png（另出一张 2 倍放大的特写）。
##
## 摆法说明：直接往 `_floaters` 里塞几条**真实结构**的飘字（pos/text/col/start/dur），
## 把 start 往回拨，就能把任意动画帧定格下来。这样能同时看到普通 / 重击 / 致命 /
## 治疗 / 中毒 五种配色，而不用真的打一场。
## ⚠️ 这是**展示用**摆法，不验证结算逻辑；结算口径看 test_engine 的 R770 段。

const UiThemeRef = preload("res://scripts/ui_theme.gd")


func _initialize() -> void:
	_m.call_deferred()


func _setup_run() -> void:
	# 绝不写玩家真实档案或存档。
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
	# 教程弹层按 `ProfileData.is_tutorial_seen()` 判定（不是 `_tutorial_finished`）。
	for tid: String in [TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tid)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> Image:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r770_%s.png" % name)
	print("[r770] SAVED %s %s" % [name, str(img.get_size())])
	return img


func _crop_zoom(img: Image, rect: Rect2, name: String, k: int) -> void:
	var ri := Rect2i(rect.position, rect.size)
	ri.position.x = maxi(0, ri.position.x)
	ri.position.y = maxi(0, ri.position.y)
	ri.size.x = mini(ri.size.x, img.get_width() - ri.position.x)
	ri.size.y = mini(ri.size.y, img.get_height() - ri.position.y)
	if ri.size.x <= 8 or ri.size.y <= 8:
		print("[r770] 裁剪区太小，跳过 %s" % name)
		return
	var crop := img.get_region(ri)
	crop.resize(crop.get_width() * k, crop.get_height() * k, Image.INTERPOLATE_LANCZOS)
	crop.save_png("res://_shots/r770_%s.png" % name)
	print("[r770] SAVED %s %s（裁剪自 %s）" % [name, str(crop.get_size()), str(ri)])


func _stuff_floaters(sc: Node, t_ratio: float) -> void:
	## 把一份「五种配色」的样本塞进飘字队列，全部定格在 t_ratio 这一帧。
	sc._floaters.clear()
	var now: int = sc._now()
	var dur := 1150
	var start := now - int(float(dur) * t_ratio)
	# 格子：挑**没有单位的空行**（第 2 / 3 行）—— 压在卡面上会被卡框切掉一半，
	# 出图什么都看不见。棋盘是 3 列 5 行，单位只在第 1 行。
	var samples: Array = [
		{"cell": Vector2i(2, 0), "text": "-3", "col": UiThemeRef.SIDE_FOE, "size": 20},
		{"cell": Vector2i(2, 1), "text": "-27", "col": UiThemeRef.SIDE_FOE, "size": 20},
		{"cell": Vector2i(2, 2), "text": "-46", "col": UiThemeRef.SIDE_FOE, "size": 20},
		{"cell": Vector2i(3, 0), "text": "+8", "col": Color("9fe0a6"), "size": 20},
		{"cell": Vector2i(3, 1), "text": "-9", "col": Color("6fbf3a"), "size": 20},
		{"cell": Vector2i(3, 2), "text": "冰封", "col": Color("8ad4f0"), "size": 16},
	]
	for s: Dictionary in samples:
		var cell: Vector2i = s["cell"]
		var txt := str(s["text"])
		var tier := DmgNumber.tier_of_amount(DmgNumber.amount_of_text(txt))
		var pal := DmgNumber.palette(tier, s["col"])
		print("[r770] %s → 数字=%s tier=%d core=%s" % [txt,
				str(DmgNumber.is_number_text(txt)), tier, (pal["core"] as Color).to_html(false)])
		sc._floaters.append({
			"pos": sc._cell_center(cell) + Vector2(0, -10),
			"sc": sc._grid_scroll,
			"text": str(s["text"]),
			"col": s["col"],
			"start": start,
			"dur": dur,
			"size": int(s["size"]),
		})
	print("[r770] 塞入 %d 条飘字，定格在 t=%.2f" % [sc._floaters.size(), t_ratio])


func _m() -> void:
	_setup_run()
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	# 收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程高亮
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

	# ① 定住段（t≈0.45）：能读出数值、看得出分级
	_stuff_floaters(sc, 0.45)
	sc.queue_redraw()
	await _wait(3)
	var img := _snap("dmg_idle")
	var band := Rect2(float(sc.GRID_X) + 10.0, float(sc.GRID_Y) + 10.0,
			float(sc.GRID_W) - 20.0, 350.0)
	_crop_zoom(img, band, "dmg_idle_zoom", 2)

	# ② 弹出瞬间（t≈0.09）：看「先冲过 1 再回落」
	_stuff_floaters(sc, 0.09)
	sc.queue_redraw()
	await _wait(3)
	var img2 := _snap("dmg_pop")
	_crop_zoom(img2, band, "dmg_pop_zoom", 2)

	# ③ 目标格伤害预览：走**选中己方单位**这条路（不是拖卡）。
	# 拖卡会叠一层整屏冷色幕，出图里数字会被压暗，看不出笔法；而两条路调的是
	# 同一个 `_draw_dmg_preview()`，看这条就够。
	sc._floaters.clear()
	var eng2 = sc.engine
	var my_cell := Vector2i(-1, -1)
	for row in 5:
		for col in 3:
			var pp = eng2.state.unit_at(Vector2i(row, col))
			if pp != null and pp.owner == GameEngine.SIDE_SELF:
				my_cell = Vector2i(row, col)
				break
		if my_cell.x >= 0:
			break
	if my_cell.x < 0:
		# 没找到就自己摆一个（用一张本职业的盟友卡）
		var probe: CardData = null
		for c3: CardData in sc.repo.reward_pool():
			if c3.card_class == RunState.player_class and c3.kind == "盟友":
				probe = sc.engine._new_own_card(c3)
				break
		if probe != null:
			my_cell = Vector2i(3, 1)
			eng2.state.place(probe, my_cell, GameEngine.SIDE_SELF)
	print("[r770] 选中己方单位 %s → 攻击目标 %s" % [str(my_cell),
			str(eng2.legal_attack_targets(my_cell))])
	if my_cell.x >= 0:
		# 保证射程里有个靶子：在它上一格放个骷髅（攻击目标由 engine 算，摆位只是给靶）
		var tgt := Vector2i(my_cell.x - 1, my_cell.y)
		if eng2.state.unit_at(tgt) == null:
			eng2.state.place(sc.repo.get_card(1053), tgt, GameEngine.SIDE_OPPONENT)
		sc._select_board(my_cell)
		# 方向 / 距离算不出合法目标时手动钉一个 —— **只为出图**；
		# 真实路径里 `attack_targets_arr` 一律由 `engine.legal_attack_targets()` 给。
		if sc.attack_targets_arr.is_empty():
			var tl: Array[Vector2i] = [tgt]
			sc.attack_targets_arr = tl
		print("[r770] 预览靶子 %s，攻击目标 %s" % [str(tgt), str(sc.attack_targets_arr)])
	await _wait(4)
	sc.queue_redraw()
	await _wait(3)
	var img3 := _snap("preview")
	var pr := Rect2(float(sc.GRID_X), float(sc.GRID_Y), float(sc.GRID_W), 340.0)
	_crop_zoom(img3, pr, "preview_zoom", 2)
	quit()
