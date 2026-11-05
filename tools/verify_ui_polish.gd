extends SceneTree
const UiTheme = preload("res://scripts/ui_theme.gd")
const TextWrap = preload("res://scripts/text_wrap.gd")
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
		if name == "class_pick":
			var panel: Rect2 = current_scene._panel_rect()
			var inner := Rect2(panel.position + Vector2(48, 0), Vector2(panel.size.x - 88, panel.size.y))
			assert(inner.encloses(current_scene._diff_left_rect()))
			assert(inner.encloses(current_scene._diff_right_rect()))
			assert(current_scene._diff_box_rect().size.x <= 180.0)
		if name == "battle":
			current_scene._banner = {}
			current_scene._map_visible = true
		if name == "shop":
			for row_index in [1, 2]:
				var shelf: Rect2 = current_scene._row_rects()[row_index]["shelf"]
				var entries: Array = current_scene._row2 if row_index == 1 else current_scene._row3
				for i in entries.size():
					var rr: Rect2 = current_scene._row23_item_rect(row_index, i)
					assert(shelf.grow_individual(12, 0, 12, 0).encloses(rr))
					assert(rr == (current_scene._row2_rect(i) if row_index == 1 else current_scene._row3_rect(i)))
					var desc: String = str(entries[i]["ench"]["desc"] if row_index == 1 else entries[i]["desc"])
					for line in TextWrap.wrap_plain(current_scene._font, desc, rr.size.x - 24.0, 11):
						assert(current_scene._font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= rr.size.x - 24.0)
		if name == "record_list" and not current_scene._rows.is_empty(): current_scene._open_detail(0)
		current_scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_src/2026-11-05_ui_polish/%s%s.png" % [name, suffix])
	print("AUDIT CAPTURE DONE")
	quit()
