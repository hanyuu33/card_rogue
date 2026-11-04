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
	for id in [9175, 9175, 9066, 9066, 9002]:
		scene.engine.state.effects.append(CardData.from_dict(repo.get_card(id).to_dict()))
	scene.engine._stoneskin_left = 12
	scene.engine.state.enemy_effects.append(CardData.from_dict(repo.get_card(9175).to_dict()))
	scene.engine.state.enemy_effects.append(CardData.from_dict(repo.get_card(9175).to_dict()))
	assert(scene._own_effect_zone_rect().encloses(scene._effect_rect(5)))
	assert(scene._enemy_zone_rect().encloses(scene._enemy_effect_rect(0)))
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_effect_strip/battle.png"))
	print("EFFECT STRIP PASS: real scene; duplicate art, simultaneous count/remaining, missing-art fallback, both sides")
	quit()
