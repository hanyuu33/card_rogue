extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	change_scene_to_file("res://scenes/class_pick.tscn")
	await process_frame
	await create_timer(0.6).timeout
	for d in [0, 5, 10]:
		RunState.set_difficulty(d)
		await _shot(current_scene, "difficulty_%d" % d)
	change_scene_to_file("res://scenes/battle.tscn")
	await process_frame
	await create_timer(1.0).timeout
	RunState.pending_rewards = [
		{"kind": "cards", "candidates": [8002, 8004, 9010], "type": "normal", "state": "pending"},
		{"kind": "cards", "legendary": true, "candidates": [9033], "state": "pending"},
		{"kind": "relic", "id": 6001, "state": "pending"},
		{"kind": "deck_delete", "state": "pending"},
		{"kind": "core", "state": "pending"}]
	var panel = current_scene._reward_panel
	panel.open()
	await create_timer(0.4).timeout
	await _shot(panel._root, "reward_list")
	panel._scroll = panel._max_scroll()
	await _shot(panel._root, "reward_list_bottom")
	print("REWARD ICONS VISUAL PASS: actual battle reward panel and class selection 0/5/10")
	quit()

func _shot(canvas, name: String) -> void:
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-04_reward_icons/%s.png" % name))
