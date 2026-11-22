extends SceneTree
## R856 实机截图：鸭蛋投手（持蛋 / 扔蛋 / 蛋碎）。
##
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r856.gd
## 结果写 res://_shots/r856_*.png。
##
## ⚠️ 这是**展示用**摆法：直接调引擎的 `_egg_pitcher_act` / `_hit_unit+_reap` 触发三段演出，
##    不验证结算（结算口径看 test_engine 的 R856 段）。


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
	rng.seed = 20261122
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
	img.save_png("res://_shots/r856_%s.png" % name)
	print("[r856] SAVED %s %s" % [name, str(img.get_size())])
	return img


func _crop_zoom(img: Image, rect: Rect2, name: String, k: int) -> void:
	var ri := Rect2i(rect.position, rect.size)
	ri.position.x = maxi(0, ri.position.x)
	ri.position.y = maxi(0, ri.position.y)
	ri.size.x = mini(ri.size.x, img.get_width() - ri.position.x)
	ri.size.y = mini(ri.size.y, img.get_height() - ri.position.y)
	if ri.size.x <= 8 or ri.size.y <= 8:
		print("[r856] 裁剪区太小，跳过 %s" % name)
		return
	var crop := img.get_region(ri)
	crop.resize(crop.get_width() * k, crop.get_height() * k, Image.INTERPOLATE_LANCZOS)
	crop.save_png("res://_shots/r856_%s.png" % name)
	print("[r856] SAVED %s %s（裁剪自 %s）" % [name, str(crop.get_size()), str(ri)])


func _find_id(eng: GameEngine, cid: int) -> Placement:
	for c: Vector2i in eng.state.board:
		var q: Placement = eng.state.unit_at(c)
		if q != null and q.card != null and q.card.id == cid:
			return q
	return null


func _cell_of(eng: GameEngine, target: Placement) -> Vector2i:
	for c: Vector2i in eng.state.board:
		if eng.state.unit_at(c) == target:
			return c
	return Vector2i(-1, -1)


func _m() -> void:
	_setup_run()
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.level_by_key("egg_pitcher")
	print("[r856] level = ", RunState.pending_level.get("name", "?"))
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)

	# 收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程高亮
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	for i in 30:
		sc._tutorial = []
		sc._tutorial_finished = true
		var tut: Node = sc.get_node_or_null(TutorialDirector.OVERLAY_NAME)
		if tut != null:
			tut.queue_free()
		paused = false
		await process_frame
	paused = false
	# ⚠️ `load_level()` 结尾会把 `_grid_scroll` 设成 max（默认滚到我方半场），
	#    敌人后排 row 0 正好在可视区外 —— 验收图必须先把滚轴归零。
	sc._grid_scroll = 0.0
	sc._show_scroll_hint = false
	sc.queue_redraw()
	await _wait(10)

	var eng: GameEngine = sc.engine
	var pitcher: Placement = _find_id(eng, GameEngine.EGG_PITCHER_ID)
	var egg: Placement = _find_id(eng, GameEngine.GOLDEN_EGG_ID)
	var pc: Vector2i = _cell_of(eng, pitcher)
	var ec: Vector2i = _cell_of(eng, egg)
	print("[r856] 投手 @%s 力量=%d 速度=%d ｜ 蛋 @%s HP=%d held=%s" % [
			str(pc), pitcher.effective_power(), pitcher.effective_speed(),
			str(ec), egg.health, str(egg.egg_held)])
	print("[r856] 无蛋判据 = %s（此刻应为 false）" % str(eng._golden_egg_of(pitcher) == null))

	# ① 开场：投手持蛋
	var img := _snap("a_idle")
	_crop_zoom(img, Rect2(float(sc.GRID_X), float(sc.GRID_Y), float(sc.GRID_W), 260.0),
			"a_idle_zoom", 2)

	# ② 扔蛋：直接调引擎那一支（界面会收到 egg_throw 事件演特效）
	print("[r856] ---- 触发扔蛋 ----")
	eng._egg_pitcher_tick(GameEngine.SIDE_OPPONENT)
	print("[r856] 无蛋判据 = %s（tick 后应为 false，它还持蛋）" % str(eng._golden_egg_of(pitcher) == null))
	var acted: bool = eng._egg_pitcher_act(pc, pitcher)
	print("[r856] _egg_pitcher_act 返回 %s（true = 行动已被扔蛋吃掉）" % str(acted))
	print("[r856] 无蛋判据 = %s（扔出去后应为 true）｜ 力量=%d 速度=%d" % [
			str(eng._golden_egg_of(pitcher) == null),
			pitcher.effective_power(), pitcher.effective_speed()])
	for i in 4:
		await _wait(4)
		_snap("b_throw_%d" % i)

	# ③ 蛋碎：打爆 → 随机史诗卡 + 投手重获金鸭蛋
	print("[r856] ---- 触发蛋碎 ----")
	var egg2: Placement = _find_id(eng, GameEngine.GOLDEN_EGG_ID)
	var ec2: Vector2i = _cell_of(eng, egg2)
	print("[r856] 蛋现在 @%s held=%s" % [str(ec2), str(egg2.egg_held)])
	var hand_before: int = eng.state.hand.size()
	eng._hit_unit(egg2, 9, "攻击", true, true)
	eng._reap(ec2)
	print("[r856] 刚 reap 完：手牌 %d｜阵营场上蛋 = %s（延迟死亡还没排空，这里应为原样）" % [
			eng.state.hand.size(), str(_find_id(eng, GameEngine.GOLDEN_EGG_ID) != null)])
	for i in 5:
		await _wait(6)
		_snap("c_break_%d" % i)
	print("[r856] 等完 30 帧：手牌 %d → %d（应 +1）｜投手 @%s｜场上蛋 = %s（应 true）" % [
			hand_before, eng.state.hand.size(), str(_cell_of(eng, pitcher)),
			str(_find_id(eng, GameEngine.GOLDEN_EGG_ID) != null)])

	img = _snap("d_after")
	_crop_zoom(img, Rect2(float(sc.GRID_X), float(sc.GRID_Y), float(sc.GRID_W), 260.0),
			"d_after_zoom", 2)
	print("[r856] DONE")
	quit()
