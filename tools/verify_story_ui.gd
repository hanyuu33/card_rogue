extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	for dims in [Vector2i(1280,720), Vector2i(1024,768), Vector2i(1600,900)]:
		root.size = dims
		change_scene_to_file("res://scenes/story.tscn")
		await process_frame
		await create_timer(0.3).timeout
		var scene = current_scene
		scene._open_detail(0)
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_src/2026-11-05_handoff_completion/story_%d.png" % dims.x)
		var event := InputEventMouseButton.new()
		event.position = scene._detail_close_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		scene._gui_input(event)
		assert(scene._sel == -1, "Close texture must use existing hit rectangle")
	change_scene_to_file("res://scenes/record_list.tscn")
	await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/2026-11-05_handoff_completion/records.png")
	print("STORY UI PASS: three window sizes and close input")
	quit()
