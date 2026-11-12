extends SceneTree
## R603 标题页实机截图（**不能 --headless**）。
## 用途：确认「嘎嘎乱杀」逐字加空格后的实际排布，以及窗口标题是否带上 Quackill。
## 输出：_review/r603_title.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	root.size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	change_scene_to_file("res://scenes/title.tscn")
	await process_frame
	await create_timer(1.5).timeout
	if current_scene != null:
		current_scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var out := "res://_review/r603_title.png"
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE")
		quit(1)
		return
	img.save_png(out)
	print("TITLE OK ", img.get_size(), "  window_title=", GameBrand.window_title())
	quit()


func _process(_delta: float) -> bool:
	return false
