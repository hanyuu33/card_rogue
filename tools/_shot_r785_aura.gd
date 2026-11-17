extends SceneTree
## R785 出图：免伤力场换成 codex 素材后，三版候选各出一张实战图给店长定。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r785_aura.gd
## 结果写 res://_shots/r785_aura_01..03.png（另有 r785_aura_fallback.png = 素材缺失兜底）。
##
## ⚠️ `CAP_AURA_VARIANT` 是 const，运行时改不了 —— 直接换场景对象的 `_cap_aura_tex`，
##    一行就能切版，不用为出图去把常量改成 var。
## ⚠️ 三张卡是相邻列（格宽 124 < 环外径 138），所以这张图**顺带**验证
##    「相邻两个满额度单位，两个环会叠在一起」到底能不能看。
## 摆法（敌方行 0..2，三列并排；⚠️ 坐标是 Vector2i(行, 列)）：
##   (2,0) 9140 赫尔墨斯    —— 额度吃满 → 带环
##   (2,1) 9188 量产型      —— 额度吃满 → 带环（与左边相邻，验重叠）
##   (2,2) 9141 阿斯克勒庇厄斯 —— 只吃 12 点（对照）→ 不许带环

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
	# R769 出图三件事 ①：教程弹层判 `ProfileData.is_tutorial_seen(id)`，不标记会盖住棋盘
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
	img.save_png("res://_shots/r785_aura_%s.png" % name)
	print("[r785] SAVED %s %s" % [name, str(img.get_size())])


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

	var cells := {"9140": Vector2i(2, 0), "9188": Vector2i(2, 1), "9141": Vector2i(2, 2)}
	var units := {}
	for k in cells.keys():
		var p: Placement = sc.engine.state.place(
				CardData.from_dict(sc.repo.get_card(int(k)).to_dict()),
				cells[k], GameEngine.SIDE_OPPONENT)
		units[k] = p
	for k in ["9140", "9188"]:
		units[k].turn_dmg_key = sc.engine.turn_number
		units[k].turn_dmg_taken = _cap_pts
	units["9141"].turn_dmg_key = sc.engine.turn_number
	units["9141"].turn_dmg_taken = 12

	for k in ["9140", "9188", "9141"]:
		print("[r785] LEFT %s=%d" % [k, sc.engine.damage_cap_left(units[k])])

	var variants := ["01", "02", "03"]
	for v in variants:
		sc._cap_aura_tex = load("res://assets/fx/fx_cap_aura_%s_card.png" % v)
		sc.queue_redraw()
		await _wait(6)
		_snap(v)

	# 兜底：素材缺失时退回程序化六边形，拍一张证明这条路没坏
	sc._cap_aura_tex = null
	sc.queue_redraw()
	await _wait(6)
	_snap("fallback")
	quit()
