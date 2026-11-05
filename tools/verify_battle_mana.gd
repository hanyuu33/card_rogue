extends SceneTree
const Hud = preload("res://scripts/battle_energy_hud.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

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
	for value in [0, 5, 6, 7, 12, 99, 125]:
		var rect := Rect2(scene.COST_X, scene.COST_Y, scene.TAP_W + 12, scene.ENERGY_H)
		var layout := Hud.value_layout(UiTheme.font_bold(), value, scene.engine.max_energy(), rect)
		assert(layout["width"] <= rect.size.x - 14, "Energy value must fit within the instrument")
		scene.engine.state.energy = value
		scene.engine._charge[GameEngine.SIDE_SELF] = 3 if value == 125 else 0
		scene.engine._dodge_active = value == 125
		scene.queue_redraw()
		await process_frame
		if DisplayServer.get_name() == "headless":
			continue
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-03_battle_mana/battle_energy_%d.png" % value))
	print("MANA HUD PASS: zero / normal / three digits + charge + dodge; real battle scene")
	current_scene.queue_free()
	await process_frame
	quit()
