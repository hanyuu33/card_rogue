extends SceneTree
## 探针 v3：验证「血条数字被永久冻结」的泄漏路径。
##
## 假设：`_fx_claim()` 会 `_fx_unqueue_hit()` 撤掉同格排着的通用受击（fx_hit）；
## 若那条 fx_hit 带了 `hold=true`（已 `_freeze_hp` 冻结过一笔），撤掉它 = 那笔待扣
## 永远没人 `_drop_hp` → 卡面数字永远停在扣血前（= 几十上百血一碰就死）。
##
## 复现：先打一笔带 seg 的伤害（龙息那种多段 → hold=true，冻结），
## 再对同一格发一次普通攻击（攻击处理会 claim → 撤掉那条 fx_hit）。

var _fails := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("✓ ", msg)
	else:
		_fails += 1
		print("✗ ", msg)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026111602
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []

	var sc: Node = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(sc)
	for i in 40:
		await process_frame
	if sc.engine == null:
		print("✗ 战斗没建起来")
		quit(1)
		return

	var repo := CardRepo.load_json()
	for cell: Vector2i in sc.engine.state.board.keys():
		if sc.engine.state.board[cell] != null:
			sc.engine.state.board.erase(cell)
	await process_frame

	var foe: Placement = sc.engine.state.place(
			CardData.from_dict(repo.get_card(9260).to_dict()), Vector2i(2, 4), GameEngine.SIDE_OPPONENT)
	var atk: Placement = sc.engine.state.place(
			CardData.from_dict(repo.get_card(8003).to_dict()), Vector2i(3, 4), GameEngine.SIDE_SELF)
	await process_frame
	_ok(foe != null and foe.health == 60, "前提：敌人 60 血")

	# ① 一笔带 seg（多段）的 10 点伤害 → fx_impact 里 fi_seg >= 0 → hold=true → 冻结 10
	sc.engine._hit_unit(foe, 10, "多段测试", true, false, -1, 0)
	await process_frame
	print("① 多段后：health=%d show=%d pending=%s delayed=%d" % [foe.health,
			sc._show_hp(foe, foe.health), str(sc._hp_pending.get(foe, [])), sc._delayed.size()])

	# ② 立刻对同一格发一次普通攻击 → 攻击处理会 _fx_claim(该格) → 撤掉刚才那条 fx_hit
	sc.engine.attack(Vector2i(3, 4), Vector2i(2, 4), GameEngine.SIDE_SELF)
	await process_frame
	print("② 攻击当帧：health=%d show=%d pending=%s delayed=%d" % [foe.health,
			sc._show_hp(foe, foe.health), str(sc._hp_pending.get(foe, [])), sc._delayed.size()])

	# ③ 等演出彻底播完（等到 _delayed 清空或超时）
	for i in 400:
		await process_frame
		if sc._delayed.is_empty() and i > 60:
			break
	print("③ 演出结束：health=%d show=%d pending=%s delayed=%d" % [foe.health,
			sc._show_hp(foe, foe.health), str(sc._hp_pending.get(foe, [])), sc._delayed.size()])

	_ok(sc._hp_pending.get(foe, []).is_empty(),
			"待扣队列应清空（现在 %s）" % str(sc._hp_pending.get(foe, [])))
	_ok(sc._show_hp(foe, foe.health) == foe.health,
			"卡面显示应等于实际血量（显示 %d / 实际 %d）" % [sc._show_hp(foe, foe.health), foe.health])

	print("== 探针：%s ==" % ("全过" if _fails == 0 else "%d 项失败（说明存在泄漏）" % _fails))
	RunState.end_run()
	quit(0 if _fails == 0 else 1)
