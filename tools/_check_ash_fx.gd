extends SceneTree
## 一次性核查：灰烬龙（1013）战吼火焰 + 龙息喷流，是否还能出画面。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_check_ash_fx.gd -- \
##     --screenshot --shotframe 9999 --target ash
##   ... --target breath
##
## 两条都走**引擎真实结算口**（_battlecry_ash / _dragon_breath_spell），
## 让 action → 界面队列 → _draw_flames() / _draw_breaths() 整条链路实跑；
## 只把演出起点钉在「刚起爆」那一帧，避免截图撞上淡出。
## 结果写 res://_shots/_check_ash_fx_<target>.png（_shots 带 .gdignore，不进包）。

var _target := "ash"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--target")
	if i >= 0 and i + 1 < args.size():
		_target = args[i + 1]
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
	rng.seed = 20261113
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/_check_ash_fx_%s.png" % name)
	print("[ashfx] SAVED %s %s" % [name, str(img.get_size())])


func _quiet(sc: Variant) -> void:
	# 与项目既有出图口径一致：收掉开场横幅、巡场缩放与教程高亮。
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc._shake_until = 0
	sc.status_text = ""
	sc.queue_redraw()


func _pin(sc: Variant) -> void:
	# 把队列起点钉在 -140ms，截到「刚起爆」而非淡出尾帧。
	var n: int = int(sc._now())
	for f in sc._flames:
		f["start"] = n - 140
	for b in sc._breaths:
		b["start"] = n - 140
	for f2 in sc._trap_fx:
		f2["start"] = n - 140
	sc.queue_redraw()


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	_setup_run()
	var t := _target
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	_quiet(sc)
	await _wait(2)
	var repo := CardRepo.load_json()
	sc.engine.state.board.clear()
	if t == "ash":
		# 灰烬龙 1013 在 (1,1)，我方三格单位 → 战吼对全场各 -4。
		sc.engine.state.place(CardData.from_dict(repo.get_card(1013).to_dict()),
				Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
		for c in [Vector2i(4, 0), Vector2i(4, 1), Vector2i(5, 2)]:
			sc.engine.state.place(CardData.from_dict(repo.get_card(8003).to_dict()),
					c, GameEngine.SIDE_SELF)
		var p: Placement = sc.engine.state.unit_at(Vector2i(1, 1))
		sc.engine._battlecry_ash(Vector2i(1, 1), p)
	elif t == "breath":
		# 远古虚骨龙 9014 在 (4,1)，受影者 9001 在 (2,1)；技能 9054 连打 5 段。
		sc.engine.state.place(CardData.from_dict(repo.get_card(9014).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		sc.engine.state.place(CardData.from_dict(repo.get_card(9001).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		sc.engine._dragon_breath_spell(GameEngine.SIDE_SELF, Vector2i(2, 1),
				repo.get_card(9054))
	else:
		print("[ashfx] UNKNOWN TARGET %s" % t)
		quit()
		return
	await _wait(4)
	_pin(sc)
	await _wait(2)
	print("[ashfx] TARGET=%s flames=%d breaths=%d bursts=%d delayed=%d fx_flame=%s fx_breath=%s" % [
			t, sc._flames.size(), sc._breaths.size(), sc._bursts.size(), sc._delayed.size(),
			str(sc._fx_flame_tex != null), str(sc._fx_breath_tex != null)])
	_snap(t)
	quit()
