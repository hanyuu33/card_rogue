extends SceneTree
## 人工录屏试验局：只负责布景，之后完全交给玩家操作。
##
## 启动：Godot --path . --script res://tools/_manual_trailer_loadout.gd
## 自检：Godot --headless --path . --script res://tools/_manual_trailer_loadout.gd -- --verify-only
##
## 隔离纪律：ProfileData / RunSave 都切到测试路径；不开 AI 桥、不开遥测、
## 不带 --demo / --screenshot（那两个会自动演示或定时退出）。

const HAND_IDS: Array[int] = [9235, 9032, 9084, 9177, 8002]
const RELIC_IDS: Array[int] = [6022, 6058]
const LEVEL_INDEX := 1  # 使魔鸭群：前排三只，适合火墙术与土元素入场分配。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	# 试验局不是新手教学：只在这份隔离测试档案里标记教程已读，
	# 防止 R744 的遮罩挡住实机画面；正式玩家档案与教程逻辑不动。
	for tut_id: String in [TutorialScript.ID_MAP_WALK, TutorialScript.ID_MAP_CHOCO,
			TutorialScript.ID_BATTLE_BASIC, TutorialScript.ID_BATTLE_ALLY,
			TutorialScript.ID_TOOL_PLACE, TutorialScript.ID_TOOL_USE]:
		ProfileData.mark_tutorial_seen(tut_id)

	# 单关试验局，不生成地图、不建立 run 存档；战斗胜负仍走正常引擎。
	RunState.run_active = false
	RunState.player_class = PlayerClass.DRUID
	RunState.difficulty = 0
	RunState.max_hp = 70
	RunState.hp = 70
	RunState.relics = RELIC_IDS.duplicate()
	RunState.spent_relics = []

	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await create_timer(0.35).timeout
	var scene = current_scene
	if scene == null or scene.engine == null:
		printerr("MANUAL LOADOUT FAIL：战斗场景没有起来")
		quit(1)
		return

	# load_level 会重建 engine / 手牌 / 首回合道具状态，所以发牌必须放在它后面。
	scene.load_level(GameLevels.builtin_levels()[LEVEL_INDEX])
	var repo: CardRepo = scene.repo
	scene.engine.state.deck.clear()
	scene.engine.state.hand.clear()
	scene.engine.state.discard.clear()
	for cid: int in HAND_IDS:
		var proto: CardData = repo.get_card(cid)
		if proto == null:
			printerr("MANUAL LOADOUT FAIL：卡牌不存在 ", cid)
			quit(2)
			return
		scene.engine.state.hand.append(CardData.from_dict(proto.to_dict()))
	scene.engine.state.energy = FieldState.ENERGY_PER_TURN
	scene.engine.self_relics = RELIC_IDS.duplicate()
	scene.selection = null
	scene._clear_hover_state()
	var ui_args := OS.get_cmdline_user_args()
	var lang_at := ui_args.find("--lang")
	var english := lang_at >= 0 and lang_at + 1 < ui_args.size() and ui_args[lang_at + 1] == "en"
	# 人工录屏也必须按语言分支：英文素材上挂一行中文状态栏，整条就废了。
	# 文案不写「试验局」——宣传素材不该带开发痕迹，中英两条观感保持一致。
	scene.status_text = ("Druid · Rabbit combo / Earth Primal / Fire Wall" if english
			else "森林精魄 · 野兔铺场 / 土元素 / 火墙术")
	scene.queue_redraw()

	var hand_names: Array[String] = []
	for card: CardData in scene.engine.state.hand:
		hand_names.append(card.card_name)
	print("MANUAL LOADOUT READY")
	print("  level=", scene.engine.state.level_name)
	print("  hand=", hand_names)
	print("  relics=", RunState.relics, " engine=", scene.engine.self_relics)
	print("  energy=", scene.engine.state.energy,
			" curse_free=", scene.engine.state.curse_free,
			" enemy_ai=", scene.engine.ai_enabled)
	print("  control=human; ai_bridge=off; demo=off; save=test-profile-only")

	# AiBridge 是项目 autoload；只有命令行显式带 --ai-bridge 才会监听。
	# 这里不再 new 一份，避免双实例争同一个端口。
	if "--directed-record" in OS.get_cmdline_user_args():
		print("  control=directed-record; ai_bridge=autoload; game_rules=normal")

	if "--verify-only" in OS.get_cmdline_user_args():
		assert(scene.engine.state.hand.size() == 5)
		assert(scene.engine.self_relics == RELIC_IDS)
		assert(scene.engine.state.curse_free)
		assert(scene.engine.ai_enabled)
		print("MANUAL LOADOUT VERIFY PASS")
		quit()


func _process(_delta: float) -> bool:
	return false
