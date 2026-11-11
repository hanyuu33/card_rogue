extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await create_timer(1.0).timeout
	var scene = current_scene
	scene._shot_pending = true
	scene._shot_frame = 100000
	scene._grid_intro_t = -1.0
	scene._grid_scroll = 0
	scene._banner = {}
	var repo := CardRepo.load_json()
	scene.engine.state.effects.clear()
	for id in [9175, 9175, 9066]:
		scene.engine.state.effects.append(CardData.from_dict(repo.get_card(id).to_dict()))
	scene.engine.state.enemy_effects.clear()
	scene.engine.state.enemy_effects.append(CardData.from_dict(repo.get_card(9175).to_dict()))
	var relics := RelicRepo.load_json().all_relics()
	RunState.relics.clear()
	for i in 10:
		RunState.relics.append(relics[i].id)
	var shown := mini(RunState.relics.size(), scene._relic_max_slots())
	for i in shown:
		assert(scene._relic_zone_rect().encloses(scene._relic_rect(i)))
		for j in i:
			assert(not scene._relic_rect(i).intersects(scene._relic_rect(j)))
	assert(scene._relic_rect(0).position.y == scene._relic_rect(4).position.y)
	assert(scene._relic_rect(5).position.y > scene._relic_rect(4).position.y)
	assert(not scene._relic_zone_rect().intersects(scene._end_turn_big_rect()))
	assert(not scene._enemy_zone_rect().intersects(scene._end_turn_big_rect()))
	assert(not scene._relic_bar_overflowed())
	await _shot(scene, "battle")
	for i in range(10, 15):
		RunState.relics.append(relics[i].id)
	assert(scene._relic_bar_overflowed())
	await _shot(scene, "overflow")
	RunState.run_active = true
	RunState.deck_ids.assign([8002, 8002, 8004, 9010])
	RunState.deck_mods.clear()
	RunState.ensure_deck_mods()
	scene.engine.state.deck.clear()
	scene.engine.state.deck.append(repo.get_card(8002))
	scene._close_zone_panels()
	scene.deck_btn.pressed.emit()
	assert(scene._run_deck_visible and not scene._deck_visible)
	assert(scene._run_deck_cards().size() == 4)
	await _shot(scene, "full_deck")
	scene._close_zone_panels()
	scene._on_left_click(scene._zone_rect("deck").get_center())
	assert(scene._deck_visible and not scene._run_deck_visible)
	assert(scene._zone_panel_cards().size() == 1)
	await _shot(scene, "draw_pile")
	print("DECK ENTRIES PASS: toolbar signal opens full 4-card deck; pile click opens remaining 1-card draw pile")
	print("BATTLE INSTRUMENTS PASS: balanced rows, 12-slot capacity, overflow, separated controls")
	quit()

func _shot(scene, name: String) -> void:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_battle_instruments/%s.png" % name))
