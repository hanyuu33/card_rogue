extends Node
## 按钮按下反馈唯一口（R151 批 2 · P1-8，动效设计 §四-8）——
## `apply_button` / `apply_chip`（按钮样式唯一口）自动给每个按钮挂上它：
## **按下 scale 0.96，松开回 1.0，线性 100ms**。自绘纪律：0 个 create_tween。
##
## 用法（一般不用手写）：`UiPressFx.attach(btn)`。
## 实现要点：作为按钮的子节点跟着按钮走（按钮销毁它也销毁）；
## 静止时 `set_process(false)`，按下 / 松开信号再唤醒 —— 不给每帧白跑。

const RATE := 0.4        # scale 变化速率（0.04 幅度 ÷ 0.1s）

var _btn: Button = null
var _t := 1.0
var _down := false


static func attach(btn: Button) -> void:
	if btn == null or btn.has_node("__UiPressFx"):
		return
	var fx = load("res://scripts/ui_press_fx.gd").new()
	fx.name = "__UiPressFx"
	fx._btn = btn
	btn.add_child(fx)
	btn.button_down.connect(fx._on_down)
	btn.button_up.connect(fx._on_up)


func _on_down() -> void:
	_down = true
	set_process(true)


func _on_up() -> void:
	_down = false
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_btn):
		queue_free()
		return
	var target := 0.96 if _down else 1.0
	if is_equal_approx(_t, target):
		_t = target
		_btn.scale = Vector2.ONE
		set_process(false)
		return
	_t = move_toward(_t, target, RATE * delta)
	_btn.pivot_offset = _btn.size / 2.0   # 绕中心缩（尺寸后变的按钮每帧重取）
	_btn.scale = Vector2(_t, _t)
