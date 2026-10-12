extends SceneTree
## R151 P0-5 探针：场景转场的硬边斜切 wipe（出图核验）。
## 驱动 SceneFx 完整走一遍「擦出 → 切场景 → 擦入」，按墙钟毫秒钉三张：
##   shot_fx_100.png  擦出中段（斜切盖到一半）
##   shot_fx_240.png  擦出完成 / 纯黑（含 SETTLE）
##   shot_fx_400.png  擦入中段（新场景上斜切退到一半）
## 用法（**必须开窗口**，别加 --headless）：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://_probe_scenefx.gd
## 判读：斜分界线必须是 45° 硬边、颜色是 INK_900（#1A1C22）——不是渐变、不是模糊。

var _fx: SceneFx = null
var _t0 := 0
var _shots := {100: false, 300: false}
var _in_shot := false     # 擦入中段那张（相位驱动，不吃帧率）
var _done := 0


func _initialize() -> void:
	_fx = SceneFx.new()
	root.add_child(_fx)          # _ready 建 _cv（全屏 Control，鼠标 IGNORE）
	_t0 = Time.get_ticks_msec()
	_fx._begin("res://scenes/title.tscn")


func _process(_delta: float) -> bool:
	var n := Time.get_ticks_msec()
	for ms in _shots.keys():
		if not _shots[ms] and n - _t0 >= int(ms):
			_shots[ms] = true
			_save("res://shot_fx_%d.png" % int(ms))
			_done += 1
	# 转场完整走完一遍之后：把擦除**钉在擦入 50%**（冻结 _t0 + 停掉 fx 的推进 +
	# 手动重绘，不吃帧率），等下一帧 _cv 以这个状态重绘完再截 ——
	# 截到的才是「标题页上斜切退到一半」。
	if not _in_shot and _fx._phase == 0 and _done >= 2:
		_fx._phase = 2
		_fx._t0 = Time.get_ticks_msec() - SceneFx.SETTLE_MS - SceneFx.IN_MS / 2
		_fx.set_process(false)        # 冻结相位（_cv 是子节点，重绘不受 set_process 影响）
		_fx._cv.queue_redraw()
		_in_shot = true
		return false
	if _in_shot:
		_in_shot = false
		_done += 1
		_save("res://shot_fx_in.png")
	if _done >= 3:
		print("PROBE FX: 全部出图完成")
		return true
	return false


func _save(path: String) -> void:
	var img := root.get_texture().get_image()   # SceneTree 脚本没有 get_viewport()，root 就是 Window
	img.save_png(ProjectSettings.globalize_path(path))
	print("PROBE FX: %s saved" % path.get_file())
