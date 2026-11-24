extends SceneTree
## R739 出图（临时）：右下角「新故事解锁」卡。跑法：
##   godot --path . --script res://tools/_shot_r739_toast.gd --resolution 1280x720

var _elapsed := 0.0
var _notified := false
var _shot := false


func _init() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _notified and _elapsed > 1.2:
		_notified = true
		StoryUnlockToast.notify("第一章-鸭鸭王国的请托", 1)
	if _notified and not _shot and _elapsed > 1.75:
		_shot = true
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://_r739_toast.png"))
		print("[R739] saved ", img.get_size())
		quit()
	return false
