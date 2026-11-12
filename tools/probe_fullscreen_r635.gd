extends SceneTree
## R635 探针：全屏 → 故事界面 → 返回标题，逐段打印窗口模式（要真窗口，不能 --headless）。
## 用法：Godot_v4.3-stable_win64_console.exe --path . --script res://tools/probe_fullscreen_r635.gd
##
## 为什么要有它：店长报「开故事界面、关闭回主界面时全屏会变窗口」。
## 代码里改窗口模式的只有 GameSettings.apply_display() 一处
## （title_scene._ready 每次回主界面都会调），所以要么是它的值被改了，
## 要么是引擎在换场景时把 mode 掉了 —— 两种都由这个探针直接读 DisplayServer 分辨。

const MODE_NAMES := {
	DisplayServer.WINDOW_MODE_WINDOWED: "WINDOWED",
	DisplayServer.WINDOW_MODE_MINIMIZED: "MINIMIZED",
	DisplayServer.WINDOW_MODE_MAXIMIZED: "MAXIMIZED",
	DisplayServer.WINDOW_MODE_FULLSCREEN: "FULLSCREEN",
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: "EXCLUSIVE_FULLSCREEN",
}

var _t := 0.0
var _phase := 0
## 判定用：故事界面里的 mode、回主界面后的 mode、强制改窗口后的 mode。
var _m1 := -1
var _m3 := -1
var _m4 := -1


func _mode_text() -> String:
	var m := DisplayServer.window_get_mode()
	return "%s(%d)" % [MODE_NAMES.get(m, "?"), m]


func _initialize() -> void:
	GameSettings.ensure_loaded()
	# 不调 set_fullscreen（那会写盘污染玩家设置）；直接落到窗口上
	# 默认：连内存值一起设 true（= 在设置页开过全屏）
	# --external：**内存值保持读盘的 false**，只把窗口设成全屏
	#             （= 玩家用 F11 / --fullscreen / 系统层面进的全屏，设置里没存过）
	if not ("--external" in OS.get_cmdline_user_args()):
		GameSettings.fullscreen = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("[R635] 0 设成全屏后 im=", _mode_text(), " GameSettings.fullscreen=", GameSettings.fullscreen)
	change_scene_to_file("res://scenes/story.tscn")
	_t = 0.0
	_phase = 1


func _process(delta: float) -> bool:
	_t += delta
	if _phase == 1 and _t > 1.2:
		_m1 = DisplayServer.window_get_mode()
		print("[R635] 1 故事界面里 im=", _mode_text(),
				" scene=", (current_scene.scene_file_path if current_scene != null else "null"))
		if current_scene != null and current_scene.has_method("_back_to_title"):
			current_scene.call("_back_to_title")
		else:
			print("[R635] !! current_scene 没有 _back_to_title，探针中止")
			quit()
			return true
		_phase = 2
		_t = 0.0
	elif _phase == 2 and _t > 1.5:
		print("[R635] 2 转场途中 im=", _mode_text())
		_phase = 3
		_t = 0.0
	elif _phase == 3 and _t > 2.0:
		_m3 = DisplayServer.window_get_mode()
		print("[R635] 3 回到主界面 im=", _mode_text(),
				" scene=", (current_scene.scene_file_path if current_scene != null else "null"),
				" GameSettings.fullscreen=", GameSettings.fullscreen)
		# 4 = 反证「设置页关全屏」必须还能生效：强制落值到窗口化（不写盘）
		GameSettings.fullscreen = false
		GameSettings.apply_display(true)
		_m4 = DisplayServer.window_get_mode()
		print("[R635] 4 强制改窗口后 im=", _mode_text())
		var fs := DisplayServer.WINDOW_MODE_FULLSCREEN
		var ok := _m1 == fs and _m3 == fs and _m4 == DisplayServer.WINDOW_MODE_WINDOWED
		print("[R635] 判定：故事界面 %s / 回主界面 %s / 强制关全屏 %s → %s" % [
				_mode_of(_m1), _mode_of(_m3), _mode_of(_m4), "PASS" if ok else "FAIL"])
		quit(0 if ok else 1)
		return true
	return false


func _mode_of(m: int) -> String:
	return str(MODE_NAMES.get(m, "?"))
