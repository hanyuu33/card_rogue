extends SceneTree
## R863 格子特效适配出图：格子缩到 124×86 之后，**所有与格子绑定的标记**还读不读得出来。
## 覆盖四套语汇（代码里刻意分开的四族）：
##   * 陷阱 7002 / 7003 —— 呼吸方框 + 中心小图标
##   * 封锁 7017（大蒜）—— 满格暗底 + 两道对角封条 + 中心蒜 + 右上角回合数
##   * 场地 8028 清泉 —— 场地边框（持久型冷色）
##   * 空袭 —— 红色四角准星 + 中心十字 + 「空袭 -N」角标
##   * 格底数值条 —— 力/程/速/生 在 86 高格里是否还压到卡面
##
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r863_fx.gd -- --screenshot --tag fx
## 输出：_shots/r863_fx.png

var _sc: Variant = null


func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


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
	var st: Variant = _sc.engine.state
	# 少放几张单位：把格子留给标记，避免「卡面 + 标记」互相遮挡看不出问题
	var units: Array = [
		[Vector2i(0, 1), 1013, GameEngine.SIDE_OPPONENT],
		[Vector2i(2, 2), 1051, GameEngine.SIDE_OPPONENT],
		[Vector2i(4, 1), 9040, GameEngine.SIDE_SELF],
		[Vector2i(5, 0), 9038, GameEngine.SIDE_SELF],
	]
	for it: Array in units:
		var rc: Vector2i = it[0]
		if st.unit_at(rc) == null:
			st.place(repo.get_card(int(it[1])), rc, it[2])
	# ① 陷阱：冰冻 (2,0) / 毒瓶 (3,2) —— 刻意选**空格**，否则标记被卡面盖住看不出比例
	st.trap_fields[Vector2i(2, 0)] = 7002
	st.trap_fields[Vector2i(3, 2)] = 7003
	# ② 封锁：大蒜 7017，剩 3 回合（同样放空格）
	st.sealed_cells[Vector2i(1, 1)] = 3
	# ③ 场地：清泉（持久型，冷色边框）
	st.set_field(repo.get_card(8028), Vector2i(3, 1), GameEngine.SIDE_SELF)
	# ④ 空袭：两格被点名
	st.air_raid_cells.clear()
	st.air_raid_cells.append(Vector2i(0, 0))
	st.air_raid_cells.append(Vector2i(2, 1))
	_sc.queue_redraw()
	await _wait(12)
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r863_fx.png")
	print("[r863fx] CELL=%.1f CELL_W=%.1f stats_h=%.1f" % [
			_sc.CELL, _sc.CELL_W, _sc.CELL_STATS_H])
	print("[r863fx] SAVED %s" % str(img.get_size()))
	print("[r863fx] DONE")
	quit()
