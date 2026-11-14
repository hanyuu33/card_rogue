extends SceneTree
## R729 事件页「正文高度」体检：把每个事件类型都实例化一遍，量 Desc 的实际高度。
##
## 用法（不能加 --headless，需要真实排版）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r729_events.gd
##
## 判据：Desc.size.y <= 2 就说明正文被 VBox 压扁了（文字看不见），
##       同时高亮层仍在原地重画名字 → 与按钮上的白字重叠。
## 出图：res://_shots/r729_ev_<kind>.png

const KINDS := ["arcane", "oblivion", "smith", "bluefish", "struggle", "whisper",
		"treasure", "moon", "snow_leopard", "gaze", "pear", "hero",
		"adventurer", "furnace", "core_contract", "divination", "card_merchant",
		"delivery", "flyer", "martial", "apple_doctor", "cave", "relic_chest"]


func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


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

		var sc: Variant = load("res://scenes/event.tscn").instantiate()
		get_root().add_child(sc)
		await _wait(24)
		var d: Label = sc.get_node_or_null("Center/Desc")
		var r: Label = sc.get_node_or_null("Center/ResultLabel")
		var c: VBoxContainer = sc.get_node_or_null("Center")
		var txt := d.text if d != null else ""
		var gr: Rect2 = c.get_global_rect() if c != null else Rect2()
		var vh := get_root().size.y
		var flag := "OK"
		if d != null and d.size.y <= 2.0 and txt.strip_edges() != "":
			flag = "** 正文被压扁 **"
		elif gr.end.y > vh - 4.0 or gr.position.y < 4.0:
			flag = "** 卡片越界 %.0f..%.0f / 屏高 %.0f **" % [gr.position.y, gr.end.y, vh]
		print("[r729] %-14s desc=%5.1fx%5.1f rows=%d card=%5.1f..%5.1f  %s" % [
				kind, d.size.x if d != null else -1.0, d.size.y if d != null else -1.0,
				txt.split("\n").size(), gr.position.y, gr.end.y, flag])
		if flag != "OK" or kind in ["arcane", "card_merchant", "moon", "hero", "smith"]:
			var img := get_root().get_texture().get_image()
			img.save_png("res://_shots/r729_ev_%s.png" % kind)
		sc.queue_free()
		await _wait(2)
	quit()
