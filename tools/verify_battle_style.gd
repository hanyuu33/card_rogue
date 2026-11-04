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
	scene._grid_scroll = 0
	scene._grid_intro_t = -1.0
	scene._banner = {}
	var repo := CardRepo.load_json()
	for id in [9002, 9066, 9175, 9002]:
		scene.engine.state.effects.append(CardData.from_dict(repo.get_card(id).to_dict()))
	assert(scene._effect_zone_max_slots() >= 6)
	assert(scene._own_effect_zone_rect().encloses(scene._effect_rect(5)))
	assert(scene._enemy_zone_rect().encloses(scene._enemy_effect_rect(scene._enemy_effect_zone_max_slots() - 1)))
	for layer in [1, 2, 3]:
		RunState.current_layer = layer
		scene._refresh_bg_texture()
		scene._grid_scroll = 0
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_battle_ui/layer_%d.png" % layer))
		scene._grid_scroll = 120
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_battle_ui/layer_%d_lower.png" % layer))
	print("BATTLE STYLE: captured three layers in real battle scene")
	scene._banner = {"text": "我方回合 · 第 2 回合", "col": Color.WHITE, "start": scene._now() - 300, "dur": 1800}
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_battle_ui/turn_banner.png"))
	quit()
