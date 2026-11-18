extends SceneTree
## R805 出图：蜂蜜（6079）在实战里的样子 —— 道具栏图标 + 己方盟友移速 +1。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r804_honey.gd
## 结果写 res://_shots/r804_*.png
##
## 三张：
##   01_battle  有蜂蜜 —— 影子猫 8006（速 5）在场，左上道具栏有蜂蜜图标
##   02_none    对照，同样站位但没有蜂蜜
##   03_icon    道具图标 1:1 放大（44px 实机尺寸 + 128px 原图并排，验抠图边缘）

const HONEY_ID := 6079
const CAT_ID := 8006      # 影子猫：1 费 1 血 速 5


func _initialize() -> void:
	_m.call_deferred()


func _setup_run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	for tid in [TutorialScript.ID_MAP_WALK, TutorialScript.ID_MAP_CHOCO,
			TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/%s.png" % name)
	print("[r805] SAVED %s %s" % [name, str(img.get_size())])


func _battle(tag: String, with_honey: bool) -> void:
	_setup_run()
	if with_honey:
		var rel: Array[int] = [HONEY_ID]
		RunState.relics = rel
	else:
		var none: Array[int] = []
		RunState.relics = none
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	# 出图惯例：清掉横幅 / 教程 / 开场演出，保证棋盘是干净的
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc.status_text = ""
	sc.engine.state.board.clear()

	var cat: Placement = sc.engine.state.place(
			CardData.from_dict(sc.repo.get_card(CAT_ID).to_dict()),
			Vector2i(1, 1), GameEngine.SIDE_SELF)
	sc.engine._relic_on_enter_buffs(cat)
	var foe: Placement = sc.engine.state.place(
			CardData.from_dict(sc.repo.get_card(9028).to_dict()),
			Vector2i(3, 3), GameEngine.SIDE_OPPONENT)
	print("[r805] %s：影子猫 卡面移速 %d / 实际 %d / honey_spd %d / 敌方 实际 %d"
			% [tag, cat.card.move_speed, cat.effective_speed(), cat.honey_spd,
			foe.effective_speed()])
	sc.queue_redraw()
	await _wait(10)
	_snap(tag)
	sc.queue_free()
	await _wait(4)


func _icon_sheet() -> void:
	## 44px（实机道具栏格子）+ 128px（原图）并排，看抠图边缘有没有灰边 / 残留水印。
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_root().add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("1b1720")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var tex: Texture2D = UiAssets.relic_icon(HONEY_ID)
	if tex == null:
		print("[r805] !! relic_icon(%d) 取不到" % HONEY_ID)
	else:
		for pair in [[44, Vector2(140, 150)], [88, Vector2(300, 150)], [256, Vector2(560, 150)]]:
			var box: float = float(pair[0])
			var pos: Vector2 = pair[1]
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = pos
			tr.size = Vector2(box, box)
			root.add_child(tr)
			var lb := Label.new()
			lb.text = "%dpx" % int(box)
			lb.position = pos + Vector2(0, box + 6)
			lb.add_theme_color_override("font_color", Color("e8dcc8"))
			root.add_child(lb)
	await _wait(8)
	_snap("r805_icon")


func _m() -> void:
	await _battle("r805_battle_honey", true)
	await _battle("r805_battle_none", false)
	await _icon_sheet()
	print("[r805] DONE")
	quit()
