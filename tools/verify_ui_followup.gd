extends SceneTree
const UiTheme = preload("res://scripts/ui_theme.gd")
func _initialize():
	_run.call_deferred()
func _run():
	root.size = Vector2i(1024, 768) if "--narrow" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	RunState.start_run(RogueMap.generate(rng, 1), 1)
	change_scene_to_file("res://scenes/shop.tscn")
	await process_frame
	await create_timer(0.5).timeout

	current_scene._force_touch = true
	await capture("shop_touch")
	var overlay := Control.new()
	current_scene.add_child(overlay)
	var tip := func():
		Mention.draw_tip(overlay, UiTheme.font(), UiTheme.font_bold(), {"kind": "relic", "id": 6035}, Vector2(400, 160))
	overlay.draw.connect(tip)
	overlay.queue_redraw()
	await capture("mention")
	overlay.queue_free()

	current_scene._start_enchant(0)
	await capture("shop_enchant")
	current_scene._enchanting = -1
	current_scene._buy_row3(0)
	await capture("shop_delete")
	change_scene_to_file("res://scenes/story.tscn")
	await process_frame
	await create_timer(0.4).timeout
	current_scene._open_detail(0)
	await capture("story_detail")
	print("SHOP POPUP PASS")
	quit()

func capture(label: String):
	current_scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/2026-11-05_ui_polish/sync_%s.png" % (label + ("_narrow" if "--narrow" in OS.get_cmdline_user_args() else "")))
