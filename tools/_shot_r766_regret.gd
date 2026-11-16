extends SceneTree
## R766 实机截图：懊悔（9265）打出后的「从弃牌区选一张其他职业卡」选卡页。
##
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r766_regret.gd
## 结果写 res://_shots/r766_regret_pick.png。
##
## 摆法：清空手牌塞一张懊悔、弃牌区放「两张其他职业卡 + 一张本职业卡」——
## 截图要能看出**候选只有那两张**（本职业那张不该出现在网格里）。


func _initialize() -> void:
	_m.call_deferred()


func _setup_run() -> void:
	# 绝不写玩家真实档案或存档。
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


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r766_%s.png" % name)
	print("[r766] SAVED %s %s" % [name, str(img.get_size())])


func _m() -> void:
	_setup_run()
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	# 收掉开场大字 / 巡场缩放 / 敌方效果弹窗 / 教程高亮（与项目既有出图口径一致）。
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc.status_text = ""

	var eng = sc.engine
	var regret: CardData = sc.repo.get_card(9265)
	eng.state.hand.clear()
	eng.state.discard.clear()
	eng.state.energy = 10
	eng.state.hand.append(eng._new_own_card(regret))

	# 弃牌区：两张其他职业卡（橙框）+ 一张本职业卡（应当被过滤掉）
	var other_ids: Array = []
	var own_id := -1
	for c: CardData in sc.repo.reward_pool():
		if c.card_class != "" and c.card_class != RunState.player_class:
			if other_ids.size() < 2:
				other_ids.append(c.id)
		elif c.card_class == RunState.player_class and own_id < 0:
			own_id = c.id
	for oid in other_ids:
		eng.state.discard.append(eng._new_own_card(sc.repo.get_card(int(oid))))
	if own_id > 0:
		eng.state.discard.append(eng._new_own_card(sc.repo.get_card(int(own_id))))

	var res: String = eng.use_spell(0)
	print("[r766] cast=%s pending=%s opts=%s discard=%d own=%d" % [
			res, str(eng.regret_pending), str(eng.regret_options()),
			eng.state.discard.size(), own_id])
	# 新手教程弹层会**暂停整棵树**并盖住底部「确认」按钮 —— 出图前先拆掉它。
	# （`TutorialDirector.disabled()` 只在 headless 为真，窗口模式下照弹。）
	var tut: Node = sc.get_node_or_null(TutorialDirector.OVERLAY_NAME)
	if tut != null:
		tut.queue_free()
		await _wait(4)
	paused = false
	sc._ensure_pick_visible("regret")
	await _wait(30)
	_snap("regret_pick")
	quit()
