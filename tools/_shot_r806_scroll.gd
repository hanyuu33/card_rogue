extends SceneTree
## R806 出图：法术卷轴（6080）—— 实战里的道具栏 + 第一次用技能卡后带「次元」的复制进手牌。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r806_scroll.gd
## 结果写 res://_shots/r806_*.png
##
## 三张：
##   before  打出前：道具栏有法术卷轴图标（额度还在 → 亮），手牌一张智慧 9005
##   after   打出后：手牌里多一张**带「次元」**的智慧，原卡进弃牌区
##   icon    图标 44 / 88 / 256 三档，验抠图边缘

const SCROLL_ID := 6080
const SKILL_ID := 9005      # 智慧：1 费技能「抽 2 张牌」（无目标，好出）
const FILLER := [8002, 8001]


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
	print("[r806] SAVED %s %s" % [name, str(img.get_size())])


func _dim_copies(hand: Array) -> int:
	var n := 0
	for c in hand:
		if c != null and c.id == SKILL_ID and c.has_affix("次元"):
			n += 1
	return n


func _battle() -> void:
	_setup_run()
	var rel: Array[int] = [SCROLL_ID]
	RunState.relics = rel
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	var sc: Variant = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	await _wait(48)
	# 出图惯例：清掉横幅 / 教程 / 开场演出
	sc._banner = {}
	sc._grid_intro_t = -1.0
	sc._ee_popup = false
	sc._tutorial = []
	sc._tutorial_finished = true
	sc._show_scroll_hint = false
	sc.status_text = ""
	sc.engine.state.board.clear()
	# ⚠️ 道具栏高亮（`relic_highlight`）读的是**引擎快照** self_relics，不是 RunState.relics
	sc.engine.self_relics = rel

	sc.engine.state.place(
			CardData.from_dict(sc.repo.get_card(9028).to_dict()),
			Vector2i(3, 3), GameEngine.SIDE_OPPONENT)
	sc.engine.state.hand.clear()
	sc.engine.state.hand.append(CardData.from_dict(sc.repo.get_card(SKILL_ID).to_dict()))
	for cid in FILLER:
		sc.engine.state.hand.append(CardData.from_dict(sc.repo.get_card(cid).to_dict()))
	sc.engine.state.energy = 5
	sc.queue_redraw()
	await _wait(60)   # 手牌是「从下方滑入」的动画，帧数少了卡还停在屏幕外
	print("[r806] before：手牌 %d 张 / 带次元 %d / 高亮 %s"
			% [sc.engine.state.hand.size(), _dim_copies(sc.engine.state.hand),
			str(sc.engine.relic_highlight(SCROLL_ID))])
	_snap("r806_before")

	var detail: String = sc.engine.use_spell(0)
	print("[r806] use_spell → ", detail)
	sc.queue_redraw()
	await _wait(60)
	var dim := _dim_copies(sc.engine.state.hand)
	var names: Array[String] = []
	for c in sc.engine.state.hand:
		if c != null:
			names.append("%s%s" % [c.card_name, "(次元)" if c.has_affix("次元") else ""])
	print("[r806] after：手牌 %d 张 [%s] / 带次元 %d / 弃牌 %d / 消耗 %d / 高亮 %s"
			% [sc.engine.state.hand.size(), ", ".join(names), dim,
			sc.engine.state.discard.size(), sc.engine.state.void_count,
			str(sc.engine.relic_highlight(SCROLL_ID))])
	if dim != 1:
		print("[r806] !! 期望恰好 1 张带次元的复制，实得 %d" % dim)
	_snap("r806_after")
	sc.queue_free()
	await _wait(4)


func _icon_sheet() -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_root().add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("1b1720")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var tex: Texture2D = UiAssets.relic_icon(SCROLL_ID)
	if tex == null:
		print("[r806] !! relic_icon(%d) 取不到" % SCROLL_ID)
	else:
		for pair in [[44, Vector2(160, 220)], [88, Vector2(320, 200)], [256, Vector2(520, 130)]]:
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
	_snap("r806_icon")


func _m() -> void:
	await _battle()
	await _icon_sheet()
	print("[r806] DONE")
	quit()
