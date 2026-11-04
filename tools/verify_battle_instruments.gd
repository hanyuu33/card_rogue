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
	for i in scene._relic_max_slots():
		assert(scene._relic_zone_rect().encloses(scene._relic_rect(i)))
		for j in i:
			assert(not scene._relic_rect(i).intersects(scene._relic_rect(j)))
	assert(scene._relic_rect(0).position.y == scene._relic_rect(2).position.y)
	assert(scene._relic_rect(3).position.y > scene._relic_rect(2).position.y)
	assert(not scene._relic_zone_rect().intersects(scene._end_turn_big_rect()))
	assert(not scene._enemy_zone_rect().intersects(scene._end_turn_big_rect()))
	assert(not scene._relic_bar_overflowed())
	await _shot(scene, "battle")
	for i in range(10, 15):
		RunState.relics.append(relics[i].id)
	assert(scene._relic_bar_overflowed())
	await _shot(scene, "overflow")
	print("BATTLE INSTRUMENTS PASS: 3-column wrap, 12 nonoverlapping slots, overflow, separated controls")
	quit()

func _shot(scene, name: String) -> void:
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_battle_instruments/%s.png" % name))
