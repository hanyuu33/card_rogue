extends SceneTree
## R810 出图：四件新道具（新月耳饰 / 太阳指环 / 海妖鱼叉 / 缺陷时钟）的实机帧。
##   ① r810_sunring.png —— 太阳指环「我方回合开始打全体敌人 3 点」的扩散环 + 道具栏新品；
##   ② r810_clock.png  —— 缺陷时钟「第 12 张牌 → 跳过敌方回合」的横幅。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r810.gd -- --screenshot
##
## 与 R667 出图同一套口径：先 `start_run()` 再实例化 battle.tscn，走玩家进战斗的同一条路；
## 档案切测试档，外部驱动另做逐文件还原。

var _sc: Variant = null


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
	rng.seed = 20261119
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r810_%s.png" % name)
	print("[r810] SAVED %s %s" % [name, str(img.get_size())])


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	_setup_run()
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	_sc = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(_sc)
	await _wait(48)
	# 与项目既有出图口径一致：收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程高亮
	_sc._banner = {}
	_sc._grid_intro_t = -1.0
	_sc._ee_popup = false
	_sc._tutorial = []
	_sc._tutorial_finished = true
	_sc._show_scroll_hint = false
	_sc.status_text = ""
	# 四件新道具铺进右栏（新月耳饰带角标「3」），并塞两只敌人保证「全体」有目标
	var ids: Array[int] = [6081, 6082, 6083, 6084]
	RunState.relics = ids
	_sc.engine.self_relics = ids
	RunState.crescent_battles = 0
	var _repo: CardRepo = CardRepo.load_json()
	for rc: Vector2i in [Vector2i(1, 0), Vector2i(1, 2)]:
		if _sc.engine.state.unit_at(rc) == null:
			_sc.engine.state.place(_repo.get_card(1011), rc, GameEngine.SIDE_OPPONENT)
	_sc.queue_redraw()
	await _wait(6)
	# ① 太阳指环：真事件口 → `_on_engine_action` → `_battle_fx` / `_bursts` / 飘字
	_sc.engine._sun_ring_tick()
	print("[r810] SUNRING fx=%d bursts=%d floaters=%d" % [
			_sc._battle_fx.size(), _sc._bursts.size(), _sc._floaters.size()])
	# 演出钉在「起爆后 240ms」那一帧（扩散环半程，不是刚冒头也不是淡出）
	await _wait(14)
	_sc.queue_redraw()
	await _wait(2)
	_snap("sunring")
	# ② 缺陷时钟：横幅 + 震屏 + 表盘金脉冲
	_sc.engine.action.emit("defect_clock", {"at": 12})
	await _wait(8)
	_sc.queue_redraw()
	await _wait(2)
	_snap("clock")
	print("[r810] DONE")
	quit()
