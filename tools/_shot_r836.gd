extends SceneTree
## R836 出图：缺陷时钟「时针转动」演出的四帧。
##   ① r836_clock_10.png —— 弹入（指针在 12 点）
##   ② r836_clock_40.png —— 转到约 1/2 圈
##   ③ r836_clock_72.png —— 接近一整圈（慢下来）
##   ④ r836_clock_90.png —— 卡住 + 抖动
##
## 用法（**不能加 --headless**，否则渲染不出图）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r836.gd

var _sc: Variant = null


func _initialize() -> void:
	_m.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	_hide_tutorial(get_root())          # 出图不要教程气泡挡着
	var img := get_root().get_texture().get_image()
	img.save_png("res://_shots/r836_%s.png" % name)
	print("[r836] SAVED %s" % name)


func _hide_tutorial(n: Node) -> void:
	for ch in n.get_children():
		if String(ch.name).to_lower().contains("tutorial") and ch is CanvasItem:
			(ch as CanvasItem).visible = false
		_hide_tutorial(ch)


func _hold(t: float) -> void:
	## 把这段 fx 的起点往后推，让当前时刻正好落在 t（0~1）—— 出图才能定帧
	_sc._clock_fx["start"] = _sc._now() - int(float(sc_dur()) * t)
	_sc.queue_redraw()


func sc_dur() -> int:
	return 1150


func _m() -> void:
	DirAccess.make_dir_recursive_absolute("res://_shots")
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	RunState.reset()
	RunState.pending_rewards = []
	UiGate.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	RunState.start_run(RogueMap.generate(rng))
	RunState.relic_choice = []
	RunState.pending_node = {"type": "battle"}
	RunState.pending_level = GameLevels.builtin_levels()[0]
	_sc = load("res://scenes/battle.tscn").instantiate()
	get_root().add_child(_sc)
	await _wait(48)
	_sc._banner = {}
	_sc._grid_intro_t = -1.0
	_sc._ee_popup = false
	_sc._tutorial = []
	_sc._tutorial_finished = true
	_sc._show_scroll_hint = false
	_sc.status_text = ""
	var ids: Array[int] = [6084]
	RunState.relics = ids
	RunState.spent_relics = []
	_sc.engine.self_relics = ids
	# 指针起始位置对照用：不走引擎结算，只起演出
	_sc._start_clock_fx()
	print("[r836] face_tex=%s  center=%s" % [
			str(UiAssets.clock_face() != null),
			str(_sc._fx_pos(_sc._clock_fx))])
	for t in [0.10, 0.40, 0.72, 0.90]:
		_hold(t)
		await _wait(3)
		_snap("clock_%02d" % int(t * 100))
	# ★ 真实触发：第 12 张 → `_clock_maybe_switch()` → action.emit → handler 起动画 + end_turn(true)
	# 直接压计数口（不经 play_from_hand：本场景的手牌/落位限制会拦下「凭空塞一张」），
	# 走的仍是**同一个 emit → handler → 换回合**链路，验的就是「动画与换回合同步」。
	var cd := CardRepo.load_json().get_card(8006)
	_sc.engine._clock_plays = 11
	var hand_before: int = _sc.engine.state.hand.size()
	var turn_before: int = _sc.engine.turn_number
	_sc.engine._note_card_played(GameEngine.SIDE_SELF, CardData.from_dict(cd.to_dict()))
	_sc.engine._clock_maybe_switch()
	print("[r836] REAL trigger → 手牌 %d→%d，回合 %d→%d，动画在播=%s，opp_turns=%d" % [
			hand_before, _sc.engine.state.hand.size(),
			turn_before, _sc.engine.turn_number,
			str(not _sc._clock_fx.is_empty()), _sc.engine.opp_turns])
	await _wait(14)      # ≈ 200ms，指针转过 1/4 圈
	print("[r836] plays=%d left=%d badge=\"%s\" relics=%s spent=%s" % [
			_sc.engine._clock_plays, _sc.engine.defect_clock_left(),
			RunState.relic_badge_text(6084, _sc.engine.defect_clock_left()),
			str(RunState.relics), str(RunState.spent_relics)])
	# ⚠️ 取图会拿到**上一帧**的 framebuffer：角标在触发后要消失，
	#    不强制重绘 + 多等两帧的话，图上还挂着触发前的「12」。
	_sc.queue_redraw()
	await _wait(3)
	_snap("real_mid")
	print("[r836] DONE")
	quit()
