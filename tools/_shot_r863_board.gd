extends SceneTree
## R863 战场版式出图：新卡框 / 格底数值 / 免滚动。
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r863_board.gd -- --screenshot --tag before
## 输出：_shots/r863_board_<tag>.png
##
## 与 R810 同一套口径：先 start_run() 再实例化 battle.tscn，走玩家进战斗的同一条路。
## 铺满 6×3 战场（敌 row0~2 / 我 row3~5），保证「满场」这一最坏情况一次看清。

var _sc: Variant = null
var _tag := "board"


func _initialize() -> void:
	_tag = _arg("--tag", "board")
	_m.call_deferred()


func _arg(key: String, dflt: String) -> String:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == key and i + 1 < a.size():
			return a[i + 1]
	return dflt


func _setup_run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r863_%s.png" % name)
	print("[r863] SAVED %s %s" % [name, str(img.get_size())])


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	_setup_run()
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	_sc = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(_sc)
	await _wait(48)
	_sc._banner = {}
	_sc._grid_intro_t = -1.0
	_sc._ee_popup = false
	_sc._tutorial = []
	_sc._tutorial_finished = true
	_sc._show_scroll_hint = false
	_sc.status_text = ""
	var repo: CardRepo = CardRepo.load_json()
	# 敌方 row 0~2：混合盟友 / 工事 / 带字段与状态
	var foes: Array = [
		[Vector2i(0, 0), 1011], [Vector2i(0, 1), 1055], [Vector2i(0, 2), 1013],
		[Vector2i(1, 0), 1031], [Vector2i(1, 1), 1050], [Vector2i(1, 2), 1051],
		[Vector2i(2, 0), 1061], [Vector2i(2, 1), 1071], [Vector2i(2, 2), 9001],
	]
	for it: Array in foes:
		var rc: Vector2i = it[0]
		if _sc.engine.state.unit_at(rc) == null:
			_sc.engine.state.place(repo.get_card(int(it[1])), rc, GameEngine.SIDE_OPPONENT)
	# 我方 row 3~5：盟友 + 工事（工事也要出数值，验证卡面一致）
	var mine: Array = [
		[Vector2i(3, 0), 8004], [Vector2i(3, 1), 8018], [Vector2i(3, 2), 8060],
		[Vector2i(4, 0), 8001], [Vector2i(4, 1), 9040], [Vector2i(4, 2), 9016],
		[Vector2i(5, 0), 9038], [Vector2i(5, 1), 8005], [Vector2i(5, 2), 8074],
	]
	for it: Array in mine:
		var rc: Vector2i = it[0]
		if _sc.engine.state.unit_at(rc) == null:
			_sc.engine.state.place(repo.get_card(int(it[1])), rc, GameEngine.SIDE_SELF)
	# 一格受伤 / 一格沉睡，验证染色与状态槽
	var hurt: Placement = _sc.engine.state.unit_at(Vector2i(4, 1))
	if hurt != null:
		hurt.health = maxi(1, hurt.health - 3)
	_sc.queue_redraw()
	await _wait(10)
	print("[r863] CELL=%.1f CELL_W=%.1f scrollable=%s scroll=%.1f content_h=%.1f" % [
			_sc.CELL, _sc.CELL_W, str(_sc._grid_scrollable()), _sc._grid_scroll,
			_sc.GRID_CONTENT_H])
	_snap(_tag)
	print("[r863] DONE")
	quit()
