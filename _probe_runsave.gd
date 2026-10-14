extends SceneTree
## 探针：续档 round-trip —— 开一局 → 改动 → save → 复位 → load → 逐字段断言一致。
## 重点验证：RNG 续档（读档后下一次摇点 == 存盘时即将摇出的值）、map_cells / boss_pick /
## relics / deck / pending_rewards 原样恢复，以及 end_run 会清档。

var _fails := 0

func _ck(name: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("  FAIL ", name)
	else:
		print("  ok   ", name)


func _reset_live() -> void:
	## 模拟"进程重启"：把 RunState 复位成和存档明显不同的哨兵值。
	## ⚠️ 不能调 end_run()（它会清掉刚存的档），所以直接逐字段打脸。
	RunState.max_hp = 50
	RunState.hp = 50
	RunState.run_active = false
	RunState.deck_ids = []
	RunState.map_cells = []
	RunState.current_layer = GameLayers.LAYER_DEFAULT
	RunState.current_node_id = -1
	RunState.cleared_ids = []
	RunState.chocolate = 0
	RunState.boss_pending = false
	RunState.player_class = ""
	RunState.battle_wins = 0
	RunState.elite_wins = 0
	RunState.used_levels = []
	RunState.boss_pick = {}
	RunState.revenge_pending = false
	RunState.relics = []
	RunState.skipped_relics = []
	RunState.duck_revive_chance = 100
	RunState.run_seed = 0
	RunState.run_rng = RandomNumberGenerator.new()
	RunState.run_rng.seed = 1
	RunState.pending_rewards = []
	RunState.relic_choice = []
	RunState.pending_relic = -1
	RunState.pending_relic_drop = -1
	RunState.pending_deck_edit = ""
	RunState.pending_event = ""


func _init() -> void:
	RunSave.clear_save()
	_ck("clean_slate_no_save", not RunSave.has_save())

	# --- 开局 + 改动，造一个"进行到一半"的局 ---
	RunState.start_run([], GameLayers.LAYER_DEFAULT, "森林精魄")
	if not RunState.relic_choice.is_empty():
		RunState.choose_start_relic(RunState.relic_choice[0])
	RunState.add_card(8004)
	RunState.gain_relic(6001)          # 类固醇：max_hp + 6
	RunState.take_damage(7)
	var av := RunState.available_nodes()
	if not av.is_empty():
		RunState.advance(int((av[0] as Dictionary)["id"]))
	RunState.queue_relic_reward(6005)
	for i in 3:
		RunState.run_rng.randi()        # 推一推随机链，制造"中段"状态

	var exp_max_hp: int = RunState.max_hp
	var exp_hp: int = RunState.hp
	var exp_deck: Array = RunState.deck_ids.duplicate()
	var exp_node: int = RunState.current_node_id
	var exp_cleared: Array = RunState.cleared_ids.duplicate()
	var exp_choco: int = RunState.chocolate
	var exp_seed: int = RunState.run_seed
	var exp_cls: String = RunState.player_class
	var exp_boss: String = str(RunState.boss_pick.get("name", ""))
	var exp_map: int = RunState.map_cells.size()
	var exp_pend: int = RunState.pending_rewards.size()

	# --- 存盘（此刻存下 rng.state = S）---
	_ck("save_run_ok", RunSave.save_run())
	_ck("has_save_true", RunSave.has_save())
	# 存盘后、消费一次：这个值就是"存档状态 S 即将摇出的下一个数"
	var expected_next: int = RunState.run_rng.randi()

	# --- 进程重启：打脸复位 → 读档 ---
	_reset_live()
	_ck("load_run_ok", RunSave.load_run())
	_ck("run_active_restored", RunState.run_active)
	_ck("max_hp", RunState.max_hp == exp_max_hp)
	_ck("hp", RunState.hp == exp_hp)
	_ck("deck_equal", RunState.deck_ids == exp_deck)
	_ck("deck_has_8004", RunState.deck_ids.has(8004))
	_ck("current_node", RunState.current_node_id == exp_node)
	_ck("cleared_equal", RunState.cleared_ids == exp_cleared)
	_ck("chocolate", RunState.chocolate == exp_choco)
	_ck("run_seed", RunState.run_seed == exp_seed)
	_ck("player_class", RunState.player_class == exp_cls)
	_ck("boss_pick_name", str(RunState.boss_pick.get("name", "")) == exp_boss)
	_ck("map_cells_size", RunState.map_cells.size() == exp_map)
	_ck("relic_6001", RunState.relics.has(6001))
	_ck("pending_rewards_size", RunState.pending_rewards.size() == exp_pend)
	_ck("map_cell0_is_dict", RunState.map_cells.size() > 0 and RunState.map_cells[0] is Dictionary)

	# --- RNG 续档：读档后第一次摇点必须 == 存盘时即将摇出的值 ---
	var got_next: int = RunState.run_rng.randi()
	_ck("rng_continuity", got_next == expected_next)

	# --- R167：end_run(false) 只复位内存，**保留续档**（「返回标题」后可继续）---
	_ck("save_again_ok", RunSave.save_run())
	RunState.end_run(false)
	_ck("end_run_false_keeps_save", RunSave.has_save())
	_ck("end_run_false_resets_memory",
			not RunState.run_active and RunState.deck_ids.is_empty())
	_ck("load_after_back_to_title", RunSave.load_run())
	_ck("restored_after_back", RunState.run_active \
			and RunState.deck_ids.size() == exp_deck.size())

	# --- 生命周期：真结束（通关 / 失败）→ end_run() 清档（非回放）---
	RunState.end_run()
	_ck("end_run_clears_save", not RunSave.has_save())

	print("RUNSAVE_PROBE fails=", _fails)
	quit(_fails)
