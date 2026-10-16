extends Node
## R186：安卓返回键 → 合成 Esc（标题界面除外：那里按返回 = 退出 App）。
##
## 背景：Godot 4.3 安卓上按返回键会向所有节点发 NOTIFICATION_WM_GO_BACK_REQUEST，
## 且默认 quit_on_go_back=true（按一下直接退 App）。本层把默认退出关掉，
## 把返回键翻译成 Esc —— 各场景现有的 Esc 层级（关浮层 → 开/关菜单）原样复用，
## 不新增任何场景分支。
##
## PC 影响：桌面端永不触发该通知；quit_on_go_back 只在安卓有意义 → 零变化。

const TITLE_SCENE := "res://scenes/title.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 菜单暂停场景树时也要收得到
	get_tree().set_quit_on_go_back(false)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var cur := get_tree().current_scene
	if cur != null and cur.scene_file_path == TITLE_SCENE:
		get_tree().quit()
		return
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
