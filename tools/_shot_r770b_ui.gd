extends SceneTree
## R770b 实机截图：① 说明类飘字的胶囊徽标；② **真的把伤害卡拖到敌方单位上**的预览。
##
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r770b_ui.gd
## 结果写 res://_shots/r770b_*.png。
##
## ⚠️ 第二部分**不复用** `_demo_aoe_drag` 的摆位 —— 那条路会在棋盘上摆两个我方树人，
## 单体攻击卡会把「波及自己人」的警告也点起来。这里只放一个敌方单位，看的就是
## 「拖到单位上，那格报多少」。

const UiThemeRef = preload("res://scripts/ui_theme.gd")


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
	img.save_png("res://_shots/r770b_%s.png" % name)
	print("[r770b] SAVED %s %s" % [name, str(img.get_size())])
	return img


func _crop_zoom(img: Image, rect: Rect2, name: String, k: int) -> void:
	var ri := Rect2i(rect.position, rect.size)
	ri.position.x = maxi(0, ri.position.x)
	ri.position.y = maxi(0, ri.position.y)
	ri.size.x = mini(ri.size.x, img.get_width() - ri.position.x)
	ri.size.y = mini(ri.size.y, img.get_height() - ri.position.y)
	if ri.size.x <= 8 or ri.size.y <= 8:
		print("[r770b] 裁剪区太小，跳过 %s" % name)
		return
	var crop := img.get_region(ri)
	crop.resize(crop.get_width() * k, crop.get_height() * k, Image.INTERPOLATE_LANCZOS)
	crop.save_png("res://_shots/r770b_%s.png" % name)
	print("[r770b] SAVED %s %s（裁剪自 %s）" % [name, str(crop.get_size()), str(ri)])


func _stuff_labels(sc: Node, t_ratio: float) -> void:
	## 塞几条**真实结构**的说明类飘字（不是数字 → 走徽标分支）。
	sc._floaters.clear()
	var now: int = sc._now()
	var dur := 1150
	var start := now - int(float(dur) * t_ratio)
	var samples: Array = [
		{"cell": Vector2i(2, 0), "text": "冰封", "col": Color("8ad4f0"), "size": 16},
		{"cell": Vector2i(2, 1), "text": "隐藏能源 -3", "col": Color("c9a6f0"), "size": 15},
		{"cell": Vector2i(2, 2), "text": "接下 5", "col": Color("f0d48a"), "size": 15},
		{"cell": Vector2i(3, 0), "text": "-27", "col": UiThemeRef.SIDE_FOE, "size": 20},
	]
	for s: Dictionary in samples:
		sc._floaters.append({
			"pos": sc._cell_center(s["cell"]) + Vector2(0, -10),
			"sc": sc._grid_scroll,
			"text": str(s["text"]),
			"col": s["col"],
			"start": start,
			"dur": dur,
			"size": int(s["size"]),
		})
	print("[r770b] 塞入 %d 条飘字（徽标 3 + 数字 1），定格 t=%.2f" % [
			sc._floaters.size(), t_ratio])


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

	# ① 徽标：三种典型说明（状态名 / 带数字的说明 / 带空格的短语）+ 一个数字做同屏对照
	_stuff_labels(sc, 0.45)
	sc.queue_redraw()
	await _wait(3)
	var img := _snap("label")
	var band := Rect2(float(sc.GRID_X) + 10.0, float(sc.GRID_Y) + 10.0,
			float(sc.GRID_W) - 20.0, 320.0)
	_crop_zoom(img, band, "label_zoom", 2)
	sc._floaters.clear()

	# ② 真拖卡：一张单体伤害卡（攻击 8002）拖在敌方单位上
	var eng = sc.engine
	var foe_cell := Vector2i(2, 1)
	if eng.state.unit_at(foe_cell) == null:
		eng.state.place(sc.repo.get_card(1053), foe_cell, GameEngine.SIDE_OPPONENT)
	var atk: CardData = sc.repo.get_card(8002)
	if atk == null:
		print("[r770b] 找不到攻击卡 8002")
		quit()
		return
	var hc := CardData.from_dict(atk.to_dict())
	if eng.state.hand.is_empty():
		eng.state.hand.append(hc)
	else:
		eng.state.hand[0] = hc
	eng.state.energy = 99
	sc._banner = {}
	sc._start_drag(0, sc._cell_center(foe_cell))
	for i in 8:
		sc._drag_pos = sc._cell_center(foe_cell)
		sc.queue_redraw()
		await process_frame
	print("[r770b] 拖拽中 idx=%d 光标格=%s 单体伤害=%s" % [
			sc._drag_idx, str(foe_cell),
			str(eng.preview_spell_damage(eng.state.hand[0], foe_cell))])
	var img2 := _snap("drag")
	# 特写：只框住敌方那一格 + 卡片右缘，别把整屏冷色幕都带进来
	var c: Rect2 = sc._cell_rect(foe_cell)
	var zr := Rect2(c.position.x - 120.0, c.position.y - 30.0,
			c.size.x + 260.0, c.size.y + 90.0)
	_crop_zoom(img2, zr, "drag_zoom", 2)
	quit()
