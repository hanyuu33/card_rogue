extends SceneTree
## R780b 出图：赫尔墨斯 9140 / 量产型赫尔墨斯 9188 本回合 20 点伤害额度吃满时，
## 卡面必须同时出现**贴卡框的六边形力场环**和右上角**「免伤」图标**；
## 并且这时候挨打要飘「免伤 N」（额度满 → 引擎扣血归 0，`fx_impact` 不会发，
## 不补这条飘字的话画面上一点反应都没有）。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r780b_cap.gd
## 结果写 res://_shots/r780b_{cap,hit}.png。
##
## 摆法（敌方行 0..2，三列并排）：
##   (0,1) 9140 赫尔墨斯 —— 额度吃满 20/20  → 必须带环 + 「免伤」
##   (1,1) 9188 量产型    —— 额度吃满 20/20  → 必须带环 + 「免伤」
##   (2,1) 9141 阿斯克勒庇厄斯 —— 只吃 12 点（对照）→ 不许带环

var _cap_pts := GameEngine.HERMES_DMG_CAP


func _initialize() -> void:
	_m.call_deferred()


func _setup_run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	# R769 出图三件事 ①：教程弹层判的是 `ProfileData.is_tutorial_seen(id)`，
	# **不是** battle_scene 的 `_tutorial_finished` —— 不标记的话开场大字之后
	# 立刻弹「卷卷」把整块棋盘盖住（R780b 出图踩过）。
	for tid in [TutorialScript.ID_MAP_WALK, TutorialScript.ID_MAP_CHOCO,
			TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r780b_%s.png" % name)
	print("[r780b] SAVED %s %s" % [name, str(img.get_size())])


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
	sc.engine.state.board.clear()

	# ⚠️ 坐标是 Vector2i(行, 列)：行 0..2 = 敌方（0 最深），列 0..2。写反会三张叠成一摞。
	var cells := {"9140": Vector2i(2, 0), "9188": Vector2i(2, 1), "9141": Vector2i(2, 2)}
	var units := {}
	for k in cells.keys():
		var p: Placement = sc.engine.state.place(
				CardData.from_dict(sc.repo.get_card(int(k)).to_dict()),
				cells[k], GameEngine.SIDE_OPPONENT)
		units[k] = p
	# 记账：9140 / 9188 打满，9141 只吃 12 —— `damage_cap_left()` 的判据是「key 对得上」，
	# 所以 key 必须写成引擎当前的 `turn_number`，否则读出来还是满额度。
	for k in ["9140", "9188"]:
		units[k].turn_dmg_key = sc.engine.turn_number
		units[k].turn_dmg_taken = _cap_pts
	units["9141"].turn_dmg_key = sc.engine.turn_number
	units["9141"].turn_dmg_taken = 12

	print("[r780b] LEFT 9140=%d 9188=%d 9141=%d" % [
			sc.engine.damage_cap_left(units["9140"]),
			sc.engine.damage_cap_left(units["9188"]),
			sc.engine.damage_cap_left(units["9141"])])
	for k in cells.keys():
		print("[r780b] SLOTS %s=%s BADGE=%s" % [k, str(sc._state_slots(units[k], cells[k])),
				str(CardFace.badge_slots(units[k].card, true, sc._state_slots(units[k], cells[k])))])
	sc.queue_redraw()
	await _wait(8)
	_snap("cap")

	# 命中反馈：额度满 → 引擎扣血归 0，只有 `damage_capped` 能让画面动起来。
	sc.engine._hit_unit(units["9188"], 30, "技能", false)
	await _wait(5)
	_snap("hit")
	quit()
