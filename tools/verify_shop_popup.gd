extends SceneTree
func _initialize():
	_run.call_deferred()
func _run():
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	RunState.start_run(RogueMap.generate(rng, 1), 1)
	change_scene_to_file("res://scenes/shop.tscn")
	await process_frame
	await create_timer(0.5).timeout
	for row in [2, 3]:
		current_scene._hover = current_scene._row2_base if row == 2 else current_scene._row3_base + 2
		current_scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_src/2026-11-05_ui_polish/shop_popup_%d.png" % row)
	print("SHOP POPUP PASS")
	quit()
