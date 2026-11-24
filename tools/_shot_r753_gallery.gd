extends SceneTree
## R753 出图（临时）：测试版图鉴应全解锁、发布版仍「见过才收录」。跑法：
##   godot --path . --script res://tools/_shot_r753_gallery.gd --resolution 1600x900
##   加一个用户参数 `--rel` 拍发布版：
##   godot --path . --script res://tools/_shot_r753_gallery.gd --resolution 1600x900 -- --rel

var _elapsed := 0.0
var _done := false


func _init() -> void:
	var rel := "--rel" in OS.get_cmdline_user_args()
	GameBuild.set_test_release(1 if rel else 0)
	change_scene_to_file("res://scenes/gallery.tscn")


func _process(delta: float) -> bool:
	_elapsed += delta
	if _done or _elapsed < 1.6:
		return false
	_done = true
	var gal := current_scene
	var locked_n := 0
	var total := 0
	for c in gal._all:
		total += 1
		if gal._locked(c):
			locked_n += 1
	print("[R753] is_release=", GameBuild.is_release(), " all=", total,
			" shown=", gal._shown.size(), " locked=", locked_n)
	var img := root.get_texture().get_image()
	var tag := "release" if GameBuild.is_release() else "test"
	img.save_png(ProjectSettings.globalize_path("res://_r753_gallery_%s.png" % tag))
	print("[R753] saved ", img.get_size(), " -> ", tag)
	quit()
	return false
