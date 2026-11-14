extends SceneTree
## R699 实机探针：地图 → 右上「完整卡组」→ 点卡 → 点「详情」，全程用**真实事件注入**，
## 每一步截图，看断在哪一环。
##
## 用法（不能加 --headless）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r699_deck.gd
## 产出 _shots/r699_a_open.png / _b_tap.png / _c_detail.png

var _sc: Node = null
var _ov: PickOverlay = null


func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r699_%s.png" % name)
	print("[r699] SAVED %s %s" % [name, str(img.get_size())])


func _touch(pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _m() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261114
	RunState.start_run(RogueMap.generate(rng, GameLayers.LAYER_DEFAULT),
			GameLayers.LAYER_DEFAULT, "", 20261114)
	# ⚠️ 不清这两个，map_scene._ready 会先跳卷卷 / 选卡场景直接 return，
	#    UI（含完整卡组按钮与浏览窗）根本不会建 —— 探针会被这条骗到。
	RunState.relic_choice = []
	RunState.pending_deck_edit = ""
	RunState.pending_relic = 0
	RunState.pending_rewards = []
	_sc = load("res://scenes/map.tscn").instantiate()
	get_root().add_child(_sc)
	await _wait(30)
	print("[r699] scene=%s in_tree=%s run_active=%s run_finished=%s" % [
			str(_sc.name), str(_sc.is_inside_tree()),
			str(RunState.run_active), str(RunState.run_finished)])
	print("[r699] deck_btn=%s deck_pick=%s" % [
			str(_sc.get("_deck_btn")), str(_sc.get("_deck_pick"))])
	_sc._open_deck_view()
	await _wait(6)
	_ov = _sc.get("_deck_pick")
	print("[r699] pick=%s" % str(_ov))
	if _ov == null:
		print("[r699] ABORT: _deck_pick 没建出来")
		quit(1)
		return
	print("[r699] overlay size=%s visible=%s" % [str(_ov.size), str(_ov.visible)])
	await _snap("a_open")

	# 找一张**有效果文**的卡（木栅栏那种没有 effect_text，看不出「效果文是否画出来」）
	var kk := 0
	for i in _ov._cards.size():
		var cc: CardData = _ov._cards[i]
		if not CardText.naturalize(cc.effect_text).strip_edges().is_empty():
			kk = i
			break
	var cr: Rect2 = _ov._card_rect(kk)
	var cpos: Vector2 = _ov._clip.position + _ov._grid.position + cr.get_center()
	print("[r699] tap card #%d %s @ %s -> card_at=%d" % [
			kk, _ov._cards[kk].card_name, str(cpos), _ov._card_at(cpos)])
	await _touch(cpos)
	print("[r699] after tap: hover=%d desc=%d" % [_ov._hover_idx, _ov._desc_idx()])
	await _snap("b_tap")

	var db: Rect2 = _ov._desc_detail_rect()
	print("[r699] detail btn %s" % str(db))
	await _touch(db.get_center())
	print("[r699] after detail: visible=%s" % str(_ov._detail.visible))
	await _snap("c_detail")
	# 点任意处关闭详情（_close_soft 是 deferred，要多等两帧）
	await _touch(Vector2(640, 120))
	print("[r699] after close-tap: detail.visible=%s" % str(_ov._detail.visible))
	await _snap("d_closed")
	quit(0)
