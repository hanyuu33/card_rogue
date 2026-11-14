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
	# 文件名带物理尺寸：同一脚本要跑多档分辨率做对比，不带会互相覆盖。
	img.save_png("res://_shots/r699_%s_%dx%d.png" % [name, img.get_size().x, img.get_size().y])
	print("[r699] SAVED %s %s" % [name, str(img.get_size())])


func _touch(pos: Vector2) -> void:
	## 直接调 `_tap()`（**逻辑**坐标），不走事件注入。
	##
	## 为什么不注入：`Input.parse_input_event()` 收的是**窗口物理坐标**，而本机是 150% DPI，
	## `--resolution 1560x720` 这种非 16:9 的窗口在 Windows 上会被系统重新结算，
	## 探针拿到的 `get_screen_transform()` 与实际派发不一致 → 会误报「点卡没反应」。
	## 事件路由本身（ScreenTouch → `_gui_input` → `_tap`）已在 1280×720 与 1920×1080
	## 两档用真实注入验过；安卓走的是同一条路，坐标换算由引擎做，游戏代码不参与。
	## 这个探针只负责：**这一档屏幕下几何算得对不对、点完有没有重绘**。
	_ov._tap(pos)
	await _wait(3)


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
	print("[r699] cols=%d card=%s row_gap=%.1f grid=%s clip=%s" % [
			_ov.cols(), str(_ov._card_size()), _ov._row_gap(),
			str(_ov._grid_size()), str(_ov._clip.size)])
	await _snap("a_open")

	# 找一张**有效果文**的卡（木栅栏那种没有 effect_text，看不出「效果文是否画出来」）
	# ⚠️ 只能挑**第一行**里的卡：R700 之后一屏只露 1.4 行，落在第二行下半张的卡
	# 中心点在裁剪框之外，`_card_at()` 按设计返回 -1（先滚到那里才点得到）。
	var kk := 0
	for i in mini(_ov._cards.size(), _ov.cols()):
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
	# 关闭详情：详情层打开时主叠层 `_gui_input` 会直接 return（点击归详情层），
	# 直调 `_tap` 绕过了那层判断，所以这里走详情自己的关闭口。
	_ov._detail._close_soft()
	await _wait(4)
	print("[r699] after close-tap: detail.visible=%s" % str(_ov._detail.visible))
	await _snap("d_closed")
	quit(0)
