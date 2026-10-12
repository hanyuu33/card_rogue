extends Node
## 覆盖层入场唯一口（R151 批 2 · P1-9，动效设计 §四-9）——
## 结算 / Esc 菜单 / 奖励悬浮窗 / 卡组查看这类「瞬间出现」的面板：
## `UiPop.play(panel)` → **scale 0.92 → 1.0 + 淡入，160ms ease-out**（自绘纪律：无 Tween）。
##
## 用法：
##   UiPop.play(panel)                 # 面板缩放 + 淡入（居中型面板：Esc 菜单 / 结算）
##   UiPop.play(panel, 1.0)            # 只淡入（全屏自绘层：RewardPanel / DeckViewer / RelicViewer
##                                     #   —— 它们的压暗底条铺满全屏，一缩就露边）
##   UiPop.play(panel, 0.92, tick)     # tick: Callable(e)，每帧回调（给压暗层同步 alpha 用）
##
## 作为 panel 的子节点挂在面板上（面板销毁它也销毁）；播完自动还原 scale/modulate 并销毁。

const DUR_MS := 160.0

var _panel: Control = null
var _from := 0.92
var _tick := Callable()
var _t0 := 0


static func play(panel: Control, scale_from := 0.92, tick := Callable()) -> void:
	if panel == null:
		return
	var p = load("res://scripts/ui_pop.gd").new()
	p._panel = panel
	p._from = scale_from
	p._tick = tick
	panel.add_child(p)


func _ready() -> void:
	_t0 = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not is_instance_valid(_panel):
		queue_free()
		return
	var k := clampf(float(Time.get_ticks_msec() - _t0) / DUR_MS, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 2.0)   # ease-out
	if not is_equal_approx(_from, 1.0):
		_panel.pivot_offset = _panel.size / 2.0
		_panel.scale = Vector2.ONE * lerpf(_from, 1.0, e)
	_panel.modulate.a = e
	if _tick.is_valid():
		_tick.call(e)
	if k >= 1.0:
		_panel.scale = Vector2.ONE
		_panel.modulate.a = 1.0
		queue_free()
