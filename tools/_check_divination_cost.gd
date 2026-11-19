extends SceneTree
## 占卜室「实际扣血」+ R819 幻象不可重摇实测：真点按钮。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --headless --path . \
##     --script res://tools/_check_divination_cost.gd
##
## 判据：
##   A 满血 60/60 → 55/55（上限与当前血一起降，因为当前血被钳到新上限）
##   B 残血 30/60 → 30/55（**当前血不掉**，只有上限降）
##   C 上限 6 / 枯血 3 → 1/1（至少留 1 点，当前血被钳）
##   D 上限 5 时按钮禁用
##   E 退出重进同一房间 → 幻象不变（R819：种子 + 层 + 节点派生）
##   F 真读档（事件页回标题）→ 幻象同样不变

const EVENT_SCENE := "res://scenes/event.tscn"

var _fail := 0


func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _boot() -> void:
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119
	RunState.start_run(RogueMap.generate(rng))
	RunState.pending_event = "divination"
	RunState.pending_node = {"type": "event", "event_kind": "divination"}


func _open() -> Variant:
	var sc: Variant = load(EVENT_SCENE).instantiate()
	get_root().add_child(sc)
	await _wait(24)
	return sc


func _rolled_of(sc: Variant) -> int:
	## 场景里当下铺的幻象编号（1~4，0 = 还没定）
	return int(sc.get("_div_rolled"))


func _case(label: String, hp0: int, mhp0: int, want_hp: int, want_mhp: int) -> void:
	_boot()
	RunState.hp = hp0
	RunState.max_hp = mhp0
	var sc: Variant = await _open()
	var rb: Button = sc.get_node_or_null("Center/RestBtn")
	var res: Label = sc.get_node_or_null("Center/ResultLabel")
	if rb == null:
		print("  ✗ %s：找不到 RestBtn" % label)
		_fail += 1
		sc.queue_free()
		await _wait(2)
		return
	print("---- %s ----
  进入：%d/%d  幻象=%d  按钮=「%s」 disabled=%s" % [
			label, RunState.hp, RunState.max_hp, _rolled_of(sc),
			rb.text, str(rb.disabled)])
	if want_mhp < 0:
		var dis_ok := rb.disabled
		print("  %s 期望禁用=true 实际=%s" % ["✓" if dis_ok else "✗", str(rb.disabled)])
		if not dis_ok:
			_fail += 1
		sc.queue_free()
		await _wait(2)
		return
	rb.emit_signal("pressed")
	await _wait(6)
	print("  占卜后：%d/%d   结果行=「%s」" % [
			RunState.hp, RunState.max_hp, res.text if res != null else "?"])
	var ok: bool = RunState.hp == want_hp and RunState.max_hp == want_mhp
	print("  %s 期望 %d/%d 实际 %d/%d" % ["✓" if ok else "✗",
			want_hp, want_mhp, RunState.hp, RunState.max_hp])
	if not ok:
		_fail += 1
	sc.queue_free()
	await _wait(2)


func _m() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()

	await _case("A 满血 60/60", 60, 60, 55, 55)
	await _case("B 残血 30/60", 30, 60, 30, 55)
	await _case("C 枯血 3/6", 3, 6, 1, 1)
	await _case("D 上限 5（应禁用）", 5, 5, 0, -1)

	# E 退出重进同一房间：幻象编号必须不变
	_boot()
	RunState.hp = 40
	RunState.max_hp = 40
	var sc1: Variant = await _open()
	var roll1 := _rolled_of(sc1)
	var rb1: Button = sc1.get_node_or_null("Center/RestBtn")
	rb1.emit_signal("pressed")
	await _wait(6)
	print("---- E 退出重进 ----
  第一次：%d/%d  幻象=%d" % [RunState.hp, RunState.max_hp, roll1])
	sc1.queue_free()
	await _wait(4)
	var sc2: Variant = await _open()
	var roll2 := _rolled_of(sc2)
	print("  重进：幻象=%d" % roll2)
	var e_ok: bool = roll1 >= 1 and roll1 == roll2
	print("  %s 幻象不变（%d → %d）" % ["✓" if e_ok else "✗", roll1, roll2])
	if not e_ok:
		_fail += 1
	sc2.queue_free()
	await _wait(2)

	# F 真读档：事件页「返回标题」不落盘 → 上限会回滚（本次事件作废，与其它事件同口径）；
	# 但幻象由「种子 + 层 + 节点」派生，读回来的同一间算出的还是同一种。
	_boot()
	RunState.hp = 40
	RunState.max_hp = 40
	var node_a := RunState.current_node_id
	var saved := RunSave.save_run()
	var sc3: Variant = await _open()
	var roll_a := _rolled_of(sc3)
	var rb3: Button = sc3.get_node_or_null("Center/RestBtn")
	rb3.emit_signal("pressed")
	await _wait(6)
	print("---- F 真读档（事件页回标题）----
  存档写入=%s  占卜后=%d/%d 幻象=%d" % [
			str(saved), RunState.hp, RunState.max_hp, roll_a])
	sc3.queue_free()
	await _wait(2)
	RunState.end_run(false)        # 与 event_scene._on_back_to_title 完全一致：只清内存不写盘
	var loaded := RunSave.load_run()
	var roll_b: int = RunState.divination_roll_for(
			RunState.run_seed, RunState.current_layer, node_a, 4)
	print("  继续游戏读档=%s → %d/%d；同一间（层 %d / 节点 %d）算出幻象=%d" % [
			str(loaded), RunState.hp, RunState.max_hp,
			RunState.current_layer, node_a, roll_b])
	var f_ok: bool = loaded and roll_a >= 1 and roll_a == roll_b
	print("  %s 读档后幻象不变（%d → %d）；上限回滚属预期（事件作废）" % [
			"✓" if f_ok else "✗", roll_a, roll_b])
	if not f_ok:
		_fail += 1

	print("\n==== 结果：%s ====" % ("全部通过" if _fail == 0 else "%d 条不符" % _fail))
	quit(0 if _fail == 0 else 1)
