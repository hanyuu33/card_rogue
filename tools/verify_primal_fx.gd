extends SceneTree

var hits := 0
var death_done := false
var launch_gap := -1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var repo := CardRepo.load_json()
	var e := GameEngine.new(FieldState.new([], 30, 30, -1, "primal test", false))
	e.defer_primal_effects = true
	e.defer_death_effects = true
	var src := e.state.place(repo.get_card(9235), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var a := e.state.place(repo.get_card(9001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	var b := e.state.place(repo.get_card(9001), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	a.health = 2
	b.health = 20
	e.state.self_ally_plays = 2
	e._earth_primal_enter(src)
	assert(a.health == 2 and b.health == 20, "allocation must not deal damage")
	assert(e.primal_queue.size() == 2)
	assert(e.primal_queue[0].amount == 2 and e.primal_queue[1].amount == 7)
	assert(e.next_primal_hit().target == a)
	e.resolve_primal_hit()
	e._queue_death_effect(Vector2i(2, 1), func(): death_done = true)
	assert(not death_done)
	assert(e.next_primal_hit().target == b, "deathrattle must not block remaining batch")
	e.resolve_primal_hit()
	assert(b.health == 13 and not death_done)
	e.flush_all_death_effects()
	assert(death_done)
	print("PRIMAL RULES PASS: fixed allocation, contact-only damage, entire batch before deathrattle")
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await create_timer(1.0).timeout
	var scene = current_scene
	scene._ai_timer.stop()
	scene.engine.ai_enabled = false
	scene.engine.over = false
	scene.engine.state.board.clear()
	scene.engine.state.deck.clear()
	scene.engine.state.hand.clear()
	scene.engine.state.discard.clear()
	scene._grid_intro_t = -1.0
	scene._grid_scroll = 0
	scene._banner = {}
	var fire: Placement = scene.engine.state.place(repo.get_card(9236), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var target: Placement = scene.engine.state.place(repo.get_card(9001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	target.health = 50
	for i in 7:
		scene.engine.state.deck.append(repo.get_card(9154))
	scene.engine.action.connect(func(kind, data):
		if kind == "fx_impact" and str(data.get("source", "")) == "火元素":
			hits += 1
			assert(scene._primal_landing, "damage must occur at VFX contact")
	)
	scene.engine._fire_primal_enter(fire)
	assert(target.health == 50)
	var deadline := Time.get_ticks_msec() + 15000
	var shot := false
	while scene.engine.has_pending_primal_effects() or not scene._primal_fx.is_empty():
		await process_frame
		assert(Time.get_ticks_msec() < deadline, "sequence stalled")
		if not shot and hits > 0:
			assert(scene._primal_hit_ms == 240, ">6 hits must accelerate")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://art_src/2026-11-11_元素入场特效/fire_live.png")
			shot = true
	assert(hits == 7 and target.health == 36, "all repeated same-target hits must land")
	print("PRIMAL LIVE PASS: seven separate contacts, accelerated timing, HP 50 -> 36")
	await create_timer(1.0).timeout
	scene.engine.over = false
	scene.engine.state.board.clear()
	var earth: Placement = scene.engine.state.place(repo.get_card(9235), Vector2i(3, 1), GameEngine.SIDE_SELF)
	var victim: Placement = scene.engine.state.place(repo.get_card(9001), Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
	victim.health = 2
	var survivor: Placement = scene.engine.state.place(repo.get_card(9001), Vector2i(1, 1), GameEngine.SIDE_OPPONENT)
	survivor.health = 20
	scene.engine.state.self_ally_plays = 2
	death_done = false
	scene.engine.action.connect(func(kind, data):
		if kind == "destroy" and data.get("placement") == victim:
			scene.engine._queue_death_effect(data.cell, func():
				assert(survivor.health == 13, "deathrattle ran before final hit")
				death_done = true
			)
	)
	scene.engine._earth_primal_enter(earth)
	deadline = Time.get_ticks_msec() + 15000
	shot = false
	launch_gap = -1
	while scene.engine.has_pending_primal_effects() or not scene._primal_fx.is_empty() or scene.engine.has_pending_death_effects():
		await process_frame
		assert(Time.get_ticks_msec() < deadline)
		# R646：土元素两段必须**连着发射**（节流 70ms，按帧对齐会落在 70~120ms），
		# 而不再是一段播完（340 + 520）才起下一段。
		if launch_gap < 0 and scene._primal_fx.size() >= 2:
			launch_gap = int(scene._primal_fx[1].start) - int(scene._primal_fx[0].start)
		if (not shot and not scene._primal_fx.is_empty()
				and scene._now() > int(scene._primal_fx[0].land) + 60):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://art_src/2026-11-11_元素入场特效/earth_live.png")
			shot = true
	assert(launch_gap >= 70 and launch_gap <= 130,
			"土元素两段应背靠背发射（约 70ms），实测 %dms" % launch_gap)
	assert(death_done and survivor.health == 13)
	print("PRIMAL EARTH LIVE PASS: lethal first hit, remaining allocation, then deathrattle")
	quit()
