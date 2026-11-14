extends SceneTree
## R692b 护甲数值「实机截图」：卡面右上角圆槽里必须能读出**真值**（20 / 10），
## 而不是「9+」或干脆什么都没有。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r692b_armor.gd
## 结果写 res://_shots/r692b_armor.png。
##
## 摆法：我方 9141 阿斯克勒庇厄斯（护甲 20 = 两位数）+ 敌方 9207 量产型（护甲 10），
## 清空棋盘其余单位，两张卡并排 —— 一眼能对比「我 20 / 敌 10」是否各自落在自己的卡上。

var _foe_cell := Vector2i(3, 2)
var _self_cell := Vector2i(4, 2)


func _initialize() -> void:
	_m.call_deferred()


func _setup_run() -> void:
	# R346 / R378：绝不写玩家真实档案或存档。
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261114
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r692b_%s.png" % name)
	print("[r692b] SAVED %s %s" % [name, str(img.get_size())])


func _m() -> void:
	_setup_run()
	RunState.pending_node = {"type": "battle"}
	# 钉死同一关：不钉的话每次摇出的关卡不同，两张卡会落进不同战场背景。
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	# 与项目既有出图口径一致：收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程高亮。
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc.status_text = ""
	# 清空棋盘：只留这一对护甲单位，否则开局那批卡会把两格挤掉。
	sc.engine.state.board.clear()
	var p_self: Placement = sc.engine.state.place(
			CardData.from_dict(sc.repo.get_card(9141).to_dict()),
			_self_cell, GameEngine.SIDE_SELF)
	p_self.armor = 20
	var p_foe: Placement = sc.engine.state.place(
			CardData.from_dict(sc.repo.get_card(9207).to_dict()),
			_foe_cell, GameEngine.SIDE_OPPONENT)
	p_foe.armor = 10
	# 槽位队列只有护甲一项 → 无轮播，截图时刻不敏感；仍钉一下确认数值真的进了槽位。
	print("[r692b] SLOTS self=%s foe=%s" % [
			str(sc._state_slots(p_self, _self_cell)),
			str(sc._state_slots(p_foe, _foe_cell))])
	sc.queue_redraw()
	await _wait(6)
	_snap("armor")
	quit()
