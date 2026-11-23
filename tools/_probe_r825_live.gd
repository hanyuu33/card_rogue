extends SceneTree
## R825：非 headless 实写 / 实读 / 真场景按钮探针。只使用各系统的测试路径。

var fails := 0


func check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✓ ", msg)
	else:
		fails += 1
		printerr("  ✗ ", msg)


func _initialize() -> void:
	GameSettings.ensure_loaded()
	GameSettings.language = "zh"
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunRecord.set_test_mode()
	DailyChallenge.set_test_mode()
	_run.call_deferred()


func _new_run() -> void:
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 8252026
	RunState.start_run(RogueMap.generate(rng), GameLayers.LAYER_DEFAULT)
	RunState.relic_choice = []


func _mount(path: String) -> Node:
	var packed: PackedScene = load(path)
	var node := packed.instantiate()
	root.add_child(node)
	current_scene = node
	await process_frame
	await process_frame
	return node


func _unmount(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if current_scene == node:
		current_scene = null
	if node.get_parent() == root:
		root.remove_child(node)
	node.free()
	await process_frame


func _run() -> void:
	print("-- R825 LIVE 战斗胜利后退出 / 读档")
	_new_run()
	RunState.gold = 100
	RunState.pending_node = {"type": "battle", "id": RunState.current_node_id}
	RunState.pending_level = RunState.next_level(RunState.pending_node)
	RunState.queue_relic_reward(6005)
	var battle := await _mount("res://scenes/battle.tscn")
	battle.engine.state.hp_self = 23
	battle._show_over(true)
	var battle_gold := RunState.gold
	var battle_rewards := RunState.pending_reward_count()
	check(RunState.hp == 23 and battle_gold > 100 and battle_rewards >= 2,
			"战斗结算已产生战后血量 / 金币 / 奖励（23 / %d / %d）" % [battle_gold, battle_rewards])
	RunState.hp = RunState.max_hp
	RunState.gold = 0
	RunState.pending_rewards = []
	check(RunSave.load_run(), "战斗后真实读档：%s" % RunSave.last_error)
	check(RunState.hp == 23 and RunState.gold == battle_gold
			and RunState.pending_reward_count() == battle_rewards,
			"胜利页退出不回血、不丢金币、不吞待领奖励")
	battle._reward_panel._claim_entry(0)
	battle._reward_panel._process(0.0)
	check(RunState.has_relic(6005) and RunState.pending_reward_count() == battle_rewards - 1,
			"奖励面板实际领取一件道具")
	RunState.relics = []
	RunState.pending_rewards = []
	check(RunSave.load_run(), "领奖后真实读档：%s" % RunSave.last_error)
	print("    DEBUG reward after load: relics=", RunState.relics, " pending=", RunState.pending_rewards)
	check(RunState.relics.count(6005) == 1
			and str((RunState.pending_rewards[0] as Dictionary).get("state", "")) == RunState.REWARD_CLAIMED
			and not RunState.claim_pending_reward(0),
			"领奖后读档保持 claimed，再次领取不重复发奖")
	await _unmount(battle)

	print("-- R825 LIVE 商店成交 / 同店按钮")
	_new_run()
	RunState.set_difficulty(11)
	RunState.gold = 5000
	RunState.hp = 30
	RunState.chocolate = 3
	var shop_cell: Dictionary = {}
	for c: Dictionary in RunState.map_cells:
		if bool(c.get("shop_mark", false)):
			shop_cell = c
			break
	check(not shop_cell.is_empty(), "测试地图有一间商店")
	if shop_cell.is_empty():
		quit(1)
		return
	RunState.current_node_id = int(shop_cell["id"])
	RunState.pending_node = shop_cell
	var shop := await _mount("res://scenes/shop.tscn")
	check(RunState.shop_revisit_ok(RunState.current_node_id),
			"进店即登记同店重进，不必等正常离店")
	var bought_card := int(shop._row1[0]["card"].id)
	shop._buy_card(0)
	var trap_row := -1
	for i in shop._row2.size():
		if str(shop._row2[i].get("kind", "")) == "trap":
			trap_row = i
			break
	check(trap_row >= 0, "商店第二行有工具可买")
	if trap_row >= 0:
		shop._buy_trap(trap_row)
	var bought_trap := int(shop._row2[trap_row]["id"]) if trap_row >= 0 else -1
	for i in shop._row3.size():
		if str(shop._row3[i]["key"]) in ["maxhp", "choco", "dagger"]:
			shop._buy_row3(i)
	var expected_gold := RunState.gold
	var expected_hp := RunState.hp
	var expected_max := RunState.max_hp
	var expected_choco := RunState.chocolate
	var expected_deck := RunState.deck_ids.size()
	var expected_shop: Dictionary = RunState.shop_state_of(RunState.current_node_id).duplicate(true)
	check(RunState.deck_ids.has(bought_card) and RunState.traps.has(bought_trap)
			and RunState.has_key(RunState.DAGGER_RELIC_ID),
			"卡 / 工具 / 信物都已实际发放")
	RunState.hp = 1
	RunState.max_hp = 50
	RunState.gold = 0
	RunState.chocolate = 0
	RunState.traps = [-1, -1, -1]
	RunState.key_relics = []
	RunState.deck_ids = []
	RunState.shop_states = {}
	RunState.shop_revisit_id = -1
	check(RunSave.load_run(), "商店成交后真实读档：%s" % RunSave.last_error)
	check(RunState.gold == expected_gold and RunState.hp == expected_hp
			and RunState.max_hp == expected_max and RunState.chocolate == expected_choco
			and RunState.deck_ids.size() == expected_deck and RunState.traps.has(bought_trap)
			and RunState.has_key(RunState.DAGGER_RELIC_ID),
			"扣款 / 生命 / 巧克力 / 卡组 / 工具 / 信物与成交时一致")
	check(JSON.stringify(RunState.shop_state_of(RunState.current_node_id)) == JSON.stringify(expected_shop)
			and RunState.shop_revisit_ok(RunState.current_node_id),
			"货架 id、售罄位和同店窗口完整恢复")
	shop._setup_shop()
	print("    DEBUG shop restored: expected=", bought_card, " actual=", shop._row1[0])
	check(int(shop._row1[0]["card"].id) == bought_card and bool(shop._row1[0]["sold"]),
			"场景恢复分支不重摇，已买卡牌仍售罄")
	await _unmount(shop)

	var map := await _mount("res://scenes/map.tscn")
	paused = false   # 测试档首次进地图可能弹教程；本探针只测转场，不让教程暂停 SceneTree。
	check(map._shop_return_btn.visible, "读档后的地图显示「返回同一间商店」按钮")
	map._shop_return_btn.pressed.emit()
	await create_timer(1.6).timeout
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/shop.tscn",
			"真实点击按钮进入商店，而不是只改 pending_node")
	check(RunState.current_node_id == int(shop_cell["id"])
			and JSON.stringify(RunState.shop_state_of(RunState.current_node_id)) == JSON.stringify(expected_shop)
			and RunState.gold == expected_gold and RunState.chocolate == expected_choco,
			"同店返回不推进、不扣巧克力、不换货架、不重复扣款")
	await _unmount(current_scene)

	print("-- R825 LIVE Boss 待领奖励 / 关窗换层")
	_new_run()
	RunState.current_layer = GameLayers.LAYER_DEFAULT
	RunState.boss_beaten = true
	RunState.pending_rewards = []
	RunState.queue_relic_reward(6005)
	check(RunSave.save_run(), "Boss 待领奖励写入测试档")
	var boss_map := await _mount("res://scenes/map.tscn")
	paused = false
	check(RunState.current_layer == GameLayers.LAYER_DEFAULT and RunState.pending_reward_count() == 1,
			"Boss 奖励未领时读档留在本层，奖励不被换层清空")
	boss_map._reward_panel._btn.pressed.emit()
	boss_map._reward_panel._claim_entry(0)
	boss_map._reward_panel._process(0.0)
	boss_map._reward_panel.close()
	await create_timer(1.6).timeout
	check(RunState.current_layer == GameLayers.LAYER_TWO and RunState.pending_reward_count() == 0,
			"领完并关窗后交还原路由，正常进入第二层")

	print("R825 LIVE === %s ===" % ("全部通过" if fails == 0 else "%d 项失败" % fails))
	quit(1 if fails > 0 else 0)
