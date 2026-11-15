extends SceneTree
## R756 出图验收：苹果与医生 / 占卜室 / 契约的核心 三页的新文案与按钮。
##
## 用法（不能加 --headless，需要真实排版与出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r756_events.gd
##
## 判据：
##   * 按钮文案必须完整（不靠省略号）且 width <= 面板可用宽，否则记 **溢出**；
##   * Desc 高度 > 2（没被 VBox 压扁）；
##   * 契约的核心：结果行要提到「代偿」，且卡组里真的多了一张 9252。
## 出图：res://_shots/r756_ev_<kind>.png

const KINDS := ["apple_doctor", "divination", "core_contract"]


func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _btn_info(b: Button) -> String:
	if b == null:
		return "(null)"
	print("        btn=%-46s vis=%s dis=%s size=%.0fx%.0f min=%.0f" % [
			b.text, str(b.visible), str(b.disabled), b.size.x, b.size.y,
			b.get_combined_minimum_size().x])
	return b.text


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	for kind: String in KINDS:
		RunState.end_run()
		RunState.reset()
		RunState.pending_rewards = []
		UiGate.reset()
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261115
		RunState.start_run(RogueMap.generate(rng))
		RunState.pending_event = kind
		RunState.pending_node = {"type": "event", "event_kind": kind}

		var n_before: int = RunState.deck_ids.size()
		var sc: Variant = load("res://scenes/event.tscn").instantiate()
		get_root().add_child(sc)
		await _wait(24)

		var d: Label = sc.get_node_or_null("Center/Desc")
		var name_l: Label = sc.get_node_or_null("Center/EventName")
		print("==== [r756] %s ====" % kind)
		print("  name: %s" % (name_l.text if name_l != null else "?"))
		print("  desc: %s" % (d.text if d != null else "?"))
		print("  desc size=%.1fx%.1f" % [d.size.x if d != null else -1.0,
				d.size.y if d != null else -1.0])
		_btn_info(sc.get_node_or_null("Center/RestBtn"))
		_btn_info(sc.get_node_or_null("Center/AltBtn"))
		_btn_info(sc.get_node_or_null("Center/LeaveBtn"))

		if kind == "core_contract":
			# 真点一次「订立契约」，验代价换位：拿到「咒缚」+ 一张「代偿」进卡组
			var rb: Button = sc.get_node_or_null("Center/RestBtn")
			if rb != null and rb.visible and not rb.disabled:
				rb.emit_signal("pressed")
				await _wait(6)
				var res: Label = sc.get_node_or_null("Center/ResultLabel")
				print("  >> 点击后 result: %s" % (res.text if res != null else "?"))
			print("  >> relic 6058=%s 卡组 %d->%d  含 9252=%s" % [
					str(RunState.relics.has(6058)), n_before, RunState.deck_ids.size(),
					str(9252 in RunState.deck_ids)])

		var img := get_root().get_texture().get_image()
		img.save_png("res://_shots/r756_ev_%s.png" % kind)
		print("  >> saved _shots/r756_ev_%s.png" % kind)
		sc.queue_free()
		await _wait(2)
	quit()
