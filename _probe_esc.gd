extends SceneTree
## R148 探针：「在游戏里按 Esc 会呼出主菜单」——**真的**按一次，而不是直接调 `_menu.open()`。
##
## 走的是完整链路：`Input.parse_input_event` → 输入队列 → Viewport 派发 →
## `battle_scene._unhandled_key_input` → `UiMenu.open()` / `close()`。
## 顺带核验暂停开关（菜单打开时敌人 AI 必须停住，关闭时必须恢复 —— 漏恢复 = 游戏假死）。
##
## 用法（**必须开窗口**，别加 --headless：headless 下没有正常的 GUI 输入派发路径）：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://_probe_esc.gd
##
## 输出形如：
##   OK   Esc 打开主菜单
##   OK   菜单打开 → 场景树暂停（敌人不会继续行动）
##   OK   再按 Esc 关闭菜单
##   OK   菜单关闭 → 恢复
##   PROBE ESC: 全部通过

var _phase := 0
var _frames := 0
var _bad := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/battle.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var scene := current_scene
	if scene == null or _frames < 5:
		return false          # 等场景就绪（engine / 菜单都在 _ready 里建）
	if _phase == 0:
		_send_esc()
		_phase = 1
		_frames = 0
		return false
	if _phase == 1 and _frames >= 2:
		var m: Variant = scene.get("_menu")
		_check(m != null, "战斗场景挂上了主菜单（_menu 非空）")
		_check(m != null and m.is_open(), "Esc 打开主菜单")
		_check(paused, "菜单打开 → 场景树暂停（敌人不会继续行动）")
		_send_esc()
		_phase = 2
		_frames = 0
		return false
	if _phase == 2 and _frames >= 2:
		var m2: Variant = scene.get("_menu")
		_check(m2 != null and not m2.is_open(), "再按一次 Esc 关闭菜单")
		_check(not paused, "菜单关闭 → 恢复暂停")
		print("PROBE ESC: %s" % ("全部通过" if _bad == 0 else "%d 项失败" % _bad))
		return true
	return false


func _send_esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  OK   %s" % what)
	else:
		_bad += 1
		print("  FAIL %s" % what)
