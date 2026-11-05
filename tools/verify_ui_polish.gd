extends SceneTree
func _initialize():
	_run.call_deferred()
func _run():
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var suffix := ""
	if "--hd" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 1080)
		suffix = "_1080"
	elif "--portrait-ratio" in OS.get_cmdline_user_args():
		root.size = Vector2i(1024, 768)
		suffix = "_1024"
	for label in ["完整卡组", "返回标题", "回合结束"]:
		var button := Button.new()
		button.text = label
		root.add_child(button)
		UiTheme.apply_button(button)
		button.size = Vector2(104, 32)
		await process_frame
		var style := button.get_theme_stylebox("normal")
		var available := button.size.x - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT)
		assert(button.get_theme_font("font").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x <= available)
		button.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	RunState.start_run(RogueMap.generate(rng, 1), 1)
	RunState.relic_choice.clear()
	for name in ["title", "settings", "gallery", "class_pick", "map", "battle", "shop", "story", "record_list", "ban"]:
		change_scene_to_file("res://scenes/%s.tscn" % name)
		await process_frame
		await create_timer(0.8).timeout
		if name == "battle":
			current_scene._banner = {}
			current_scene._map_visible = true
		if name == "record_list" and not current_scene._rows.is_empty(): current_scene._open_detail(0)
		current_scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_src/2026-11-05_ui_polish/%s%s.png" % [name, suffix])
	print("AUDIT CAPTURE DONE")
	quit()
