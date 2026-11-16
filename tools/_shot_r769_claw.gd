extends SceneTree
## R769 实机截图：猴爪发进手牌的那张卡，**本回合费用 -1**。
##
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r769_claw.gd
## 结果写 res://_shots/r769_claw.png。
##
## 摆法：手牌里放**同一张卡的两张实例** —— 左（或前）那张挂 `hand_cost_turn`、
## 右那张不挂。卡面上的费数字是读 `cost_of()` 画的，所以两张并排就能直接看出差 1，
## 不用靠文字解释。
## ⚠️ 这是**展示用**摆法（正常局面不会同时有两张），真实的加卡路径先在日志里跑一遍
##    `_claw_tick()` 验证，截图只负责把「数字差 1」摆到眼前。


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
	# 教程弹层按 `ProfileData.is_tutorial_seen()` 判定（不是 `_tutorial_finished`），
	# 测试档案里这些标记是空的 → 每帧重建对话框。出图前直接标成已读，比反复清扫干净。
	for tid: String in [TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tid)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r769_%s.png" % name)
	print("[r769] SAVED %s %s" % [name, str(img.get_size())])


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
	# self_relics 声明是 Array[int]：经 Variant 赋值时字面量 [X] 会被判成无类型 Array 而报错，
	# 必须先落到带类型的局部变量再赋。
	var r769_relics: Array[int] = [GameEngine.MONKEY_CLAW_RELIC_ID]
	eng.self_relics = r769_relics

	# ① 先走一遍真实路径：确认 _claw_tick 真会给牌打标记（日志留证）
	eng.state.hand.clear()
	eng.state.hand_cost_turn.clear()
	eng.turn_number = 1
	eng._claw_tick()
	var real: CardData = null
	for c: CardData in eng.state.hand:
		if eng._other_class_card(c):
			real = c
	if real != null:
		print("[r769] 真实路径：猴爪发「%s」%d 费 → cost_of=%d，标记=%d" % [
				real.card_name, real.cost, eng.cost_of(real),
				int(eng.state.hand_cost_turn.get(real, 0))])
	else:
		print("[r769] 真实路径：本次没发到别职业卡")

	# ② 展示摆法：同一张 >=1 费的别职业卡放两张，一张挂标记
	var pick: CardData = null
	for c2: CardData in sc.repo.reward_pool():
		if c2.card_class != "" and c2.card_class != RunState.player_class \
				and c2.cost >= 1 and c2.id != GameEngine.ECHO_ID:
			pick = c2
			break
	eng.state.hand.clear()
	eng.state.hand_cost_turn.clear()
	eng.state.energy = 10
	if pick != null:
		var cheap: CardData = eng._new_own_card(pick)
		var full: CardData = eng._new_own_card(pick)
		eng.state.hand.append(cheap)
		eng.state.hand.append(full)
		eng.state.hand_cost_turn[cheap] = GameEngine.MONKEY_CLAW_DISCOUNT
		print("[r769] 展示：%s 原价 %d / 猴爪价 %d（两张同卡并排）" % [
				pick.card_name, eng.cost_of(full), eng.cost_of(cheap)])

	# 新手教程弹层会**暂停整棵树**并盖住半个屏幕 —— 出图前反复清扫。
	# （`TutorialDirector.disabled()` 只在 headless 为真，窗口模式下照弹；
	#   而且它会按 `_tutorial_finished` 每帧重建，所以要把状态标志一起按住，
	#   只 queue_free 节点是不够的。）
	for i in 30:
		sc._tutorial = []
		sc._tutorial_finished = true
		var tut: Node = sc.get_node_or_null(TutorialDirector.OVERLAY_NAME)
		if tut != null:
			tut.queue_free()
		paused = false
		await process_frame
	paused = false
	await _wait(20)

	# 手牌区在屏幕底部、正常只露半张（悬停才上浮）—— 费数字正落在被裁掉的那半张上。
	# 所以除了全景，再按 `_hand_rect()` 裁一张手牌特写放大，费数字才看得清。
	var r0: Rect2 = sc._hand_rect(0)
	var r1: Rect2 = sc._hand_rect(1)
	print("[r769] 手牌矩形 %s / %s" % [str(r0), str(r1)])
	var img := get_root().get_texture().get_image()
	_snap("claw")
	var uni := r0.merge(r1).grow(6.0)
	var rect := Rect2i(uni.position, uni.size)
	rect.position.x = maxi(0, rect.position.x)
	rect.position.y = maxi(0, rect.position.y)
	rect.size.x = mini(rect.size.x, img.get_width() - rect.position.x)
	rect.size.y = mini(rect.size.y, img.get_height() - rect.position.y)
	if rect.size.x > 8 and rect.size.y > 8:
		var crop := img.get_region(rect)
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_LANCZOS)
		crop.save_png("res://_shots/r769_claw_hand.png")
		print("[r769] SAVED claw_hand %s（裁剪自 %s）" % [str(crop.get_size()), str(rect)])
	quit()
