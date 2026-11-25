extends SceneTree
## R869 难度配色验收：角色选择界面三级配色 —— 0~5 森林绿 / 6~9 焦糖橙 / 10~13 砖红。
## 用法（**不能加 --headless**）：
##   Godot_v4.3-stable_win64_console.exe --path . --resolution 1280x720 \
##     --script res://tools/_shot_r869_diff.gd
## 输出：art_src/2026-11-25_frames/r869_diff_{green,orange,red}.png
## 三张都走真实 ClassPickScene，只改 RunState.difficulty，不碰存档。

const DIR := "res://art_src/2026-11-25_frames"
const SHOTS := [
	{"d": 4, "name": "green"},
	{"d": 6, "name": "orange"},
	{"d": 10, "name": "red"},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(DIR)
	var ps := load("res://scenes/class_pick.tscn") as PackedScene
	if ps == null:
		printerr("R869 shot: class_pick.tscn load fail")
		quit(1)
		return
	for s: Dictionary in SHOTS:
		RunState.set_difficulty(int(s["d"]))
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		for _i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img == null:
			printerr("R869 shot: no image (must not use --headless)")
			quit(1)
			return
		var path := "%s/r869_diff_%s.png" % [DIR, str(s["name"])]
		var err := img.save_png(path)
		print("SHOT ", ProjectSettings.globalize_path(path), " ", img.get_size(), " err=", err)
		inst.queue_free()
		await process_frame
	quit(0)
