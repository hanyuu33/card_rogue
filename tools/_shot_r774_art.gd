extends SceneTree
## R774 实机截图：状态特效文字（AI 素材 + 数字拼接）在战斗棋盘上的实际效果。
## 用法（不能 --headless）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r774_art.gd
## 结果写 res://_shots/r774_*.png。

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
	img.save_png("res://_shots/r774_%s.png" % name)
	print("[r774] SAVED %s %s" % [name, str(img.get_size())])
	return img


func _crop_zoom(img: Image, rect: Rect2, name: String, k: int) -> void:
	var ri := Rect2i(rect.position, rect.size)
	ri.position.x = maxi(0, ri.position.x)
	ri.position.y = maxi(0, ri.position.y)
	ri.size.x = mini(ri.size.x, img.get_width() - ri.position.x)
	ri.size.y = mini(ri.size.y, img.get_height() - ri.position.y)
	if ri.size.x <= 8 or ri.size.y <= 8:
		return
	var crop := img.get_region(ri)
	crop.resize(crop.get_width() * k, crop.get_height() * k, Image.INTERPOLATE_LANCZOS)
	crop.save_png("res://_shots/r774_%s.png" % name)


func _stuff(sc: Node, t_ratio: float) -> void:
	sc._floaters.clear()
	var now: int = sc._now()
	var dur := 1150
	var start := now - int(float(dur) * t_ratio)
	var samples: Array = [
		{"cell": Vector2i(2, 0), "text": "冰封"},
		{"cell": Vector2i(2, 1), "text": "中毒 -3"},
		{"cell": Vector2i(2, 2), "text": "燃烧 2"},
		{"cell": Vector2i(3, 0), "text": "治疗 +8"},
		{"cell": Vector2i(3, 1), "text": "眩晕"},
		{"cell": Vector2i(3, 2), "text": "嘲讽"},
		{"cell": Vector2i(4, 0), "text": "隐藏能源 -3"},
	]
	for s: Dictionary in samples:
		sc._floaters.append({
			"pos": sc._cell_center(s["cell"]) + Vector2(0, -10),
			"sc": sc._grid_scroll,
			"text": str(s["text"]),
			"col": Color("ffffff"),
			"start": start,
			"dur": dur,
			"size": 15,
		})
	print("[r774] 塞入 %d 条状态飘字，定格 t=%.2f" % [sc._floaters.size(), t_ratio])


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

	_stuff(sc, 0.5)
	sc.queue_redraw()
	await _wait(3)
	var img := _snap("art")
	var band := Rect2(float(sc.GRID_X) + 10.0, float(sc.GRID_Y) + 10.0,
			float(sc.GRID_W) - 20.0, 470.0)
	_crop_zoom(img, band, "art_zoom", 2)
	quit()
