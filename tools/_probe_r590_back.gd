extends SceneTree
## R590 出图探针：模拟「从百科点进故事页 / 图鉴页」后的返回 chip 文案。
## 用法：Godot --path . --script res://tools/_probe_r590_back.gd -- <story|gallery>
## ⚠️ 必须非 headless（headless 的 get_image() 返回 null）。

var _n := 0
var _done := false
var _scene := "story"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a == "story" or a == "gallery":
			_scene = a
	var route = load("res://scripts/ui_route.gd")
	route.set_back("res://scenes/codex.tscn")
	change_scene_to_file("res://scenes/%s.tscn" % _scene)


func _process(_delta: float) -> bool:
	_n += 1
	if _n > 40 and not _done:
		_done = true
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://screenshot_back_%s.png" % _scene))
		return true
	return false
