extends SceneTree
## R854 标题页实机截图（**不能 --headless**）：中文 / 英文两版主视觉对照。
## 用途：确认非中文界面挂的是英文版主视觉（QUACKILL 已烘焙），且标题只有一行。
## 用法：godot --path . --script res://tools/_shot_title_lang.gd -- --lang=en
## 输出：_review/r854_title_<lang>.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	var lang := "en"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			lang = a.substr(7).strip_edges()
	if lang == "":
		lang = "en"
	GameSettings.ensure_loaded()
	GameSettings.language = lang
	root.size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await create_timer(1.5).timeout
	if current_scene != null:
		current_scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var out := "res://_review/r854_title_%s.png" % lang
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE")
		quit(1)
		return
	img.save_png(out)
	print("TITLE OK ", lang, " ", img.get_size())
	quit()


func _process(_delta: float) -> bool:
	return false
