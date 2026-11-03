extends Control

func _ready() -> void:
	TopBar.set_process(false)
	TopBar.hide()
	var panel = load("res://scripts/reward_panel_adventure_v2.gd").new()
	add_child(panel)
	# Controlled sample: exercise long effect text as well as card art.
	await get_tree().create_timer(0.6).timeout
	if panel._sel < RunState.pending_rewards.size():
		var entry: Dictionary = RunState.pending_rewards[panel._sel]
		if entry.get("kind", "") == "cards":
			entry["candidates"] = [9057, 9007, 9033]
			panel._pick_sel = 0
			panel._root.queue_redraw()
	if "--screenshot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://art_src/2026-11-03_reward_adventure_v2/v2.png"))
		get_tree().quit()
