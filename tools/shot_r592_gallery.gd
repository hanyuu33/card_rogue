extends SceneTree
## R592 图鉴实机截图（**不能 --headless**）。
## 图鉴里能一次看到 6 张带 2 字段的卡（亡灵领主 / 魔像 / 城墙 / 钢铁卫士 / 压感地雷 / 忒修斯奇械），
## 用来确认「右上圆形标志」在真实列表里不抢戏、也不被稀有度缎带压住。
## 输出：art_src/2026-11-11_字段标志_R592/_review/gallery.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/gallery.tscn")
	await process_frame
	await create_timer(1.2).timeout
	if current_scene != null:
		current_scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var out := "res://art_src/2026-11-11_字段标志_R592/_review/gallery.png"
	var img := root.get_texture().get_image()
	if img == null:
		printerr("NO IMAGE")
		quit(1)
		return
	img.save_png(out)
	print("GALLERY OK ", ProjectSettings.globalize_path(out), " ", img.get_size())
	quit()


func _process(_delta: float) -> bool:
	return false
