extends SceneTree
## R786 出图：手牌整体对齐站场中轴 + 手牌数徽标跟着左移 + 暗影刺客「本回合用卡数」徽标。
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r786_hand.gd
## 结果：
##   _shots/r786_hand_rogue.png  —— 暗影刺客，self_card_plays=3 → 两个徽标并排
##   _shots/r786_hand_druid.png  —— 森林精魄，同一手牌 → 只有手牌数徽标（对照）
##
## 看图要点：棋盘 3 列的中线在 x=590（窗口中线 640），手牌扇形与底板都要落在 590 上；
## 两张图的棋盘刻意只放中列单位，一眼就能看出手牌有没有和它对齐。

var L10n = null


func _initialize() -> void:
	_m.call_deferred()


func _setup_run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	# 出图三件事①：教程弹层判 is_tutorial_seen，不标记会盖住手牌区
	for tid in [TutorialScript.ID_MAP_WALK, TutorialScript.ID_MAP_CHOCO,
			TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tid)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r786_hand_%s.png" % name)
	print("[r786] SAVED %s %s" % [name, str(img.get_size())])


func _shoot(cls: String, tag: String, plays: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	RunState.player_class = cls
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
	# 只放中列：棋盘中线一眼可见（列 = 1）
	sc.engine.state.place(CardData.from_dict(sc.repo.get_card(8003).to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	sc.engine.state.place(CardData.from_dict(sc.repo.get_card(1051).to_dict()),
			Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	# 五张手牌（够看出扇形与中线）
	sc.engine.state.hand.clear()
	for cid in [9086, 9189, 8001, 8002, 8003]:
		var cd: CardData = sc.repo.get_card(int(cid))
		if cd != null:
			sc.engine.state.hand.append(CardData.from_dict(cd.to_dict()))
	sc.engine.state.self_card_plays = plays
	sc.engine.state.energy = 9
	sc.queue_redraw()
	await _wait(6)
	_snap(tag)
	for i in sc.engine.state.hand.size():
		print("[r786]   hand[%d] rect=%s angle=%.2f" % [i, str(sc._hand_rect(i)), rad_to_deg(sc._hand_angle(i))])
	print("[r786]   base_x=%.1f badge=%s plays=%s" % [sc.HAND_BASE_X, str(sc._hand_badge_rect()), str(sc._plays_badge_rect())])
	print("[r786] %s：手牌 %d 张 / self_card_plays=%d / 徽标 %s / 扇形中线 %.1f（棋盘中线 %.1f）" % [
			tag, sc.engine.state.hand.size(), plays,
			"显示" if sc._shows_plays_badge() else "隐藏",
			(sc._hand_rect(0).position.x + sc._hand_rect(sc.engine.state.hand.size() - 1).position.x
					+ sc.HAND_CARD_W) / 2.0,
			sc.GRID_X + sc.GRID_W / 2.0])
	get_root().remove_child(sc)
	sc.queue_free()
	await _wait(4)


func _m() -> void:
	_setup_run()
	await _shoot(PlayerClass.ROGUE, "rogue", 3)
	await _shoot(PlayerClass.DRUID, "druid", 3)
	quit()
